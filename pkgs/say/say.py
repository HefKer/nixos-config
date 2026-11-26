"""Speak text through a warm local TTS daemon, queued and interruptible.

`say TEXT` (or text on stdin) queues TEXT with the daemon, which runs as a
user service (`say --daemon`) on a socket in $XDG_RUNTIME_DIR. Two voices,
both run by sherpa-onnx: `alert` (Piper lessac, kept loaded) and `read`
(Kokoro, loaded on first use and unloaded when idle). A number picks that
Kokoro speaker. Text is spoken sentence by sentence, so first audio comes
after the first sentence, and an interrupted item resumes at the sentence it
was on. Under do-not-disturb or while a game is focused only --urgent items
speak; the rest are held.
"""

import argparse
import json
import os
import re
import socket
import socketserver
import subprocess
import sys
import threading
import time
from array import array
from concurrent.futures import ThreadPoolExecutor

ROLE = "Assistant"
PIPER_THREADS = 2
KOKORO_THREADS = 4
# pw-cat buffers 100 ms by default, which delays first audio as much.
LATENCY = "30ms"


def log(*parts):
    print(*parts, flush=True)


def socket_path():
    return os.path.join(
        os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"), "say.sock"
    )


# A sentence ends at . ! ? or … (maybe then a quote or bracket) and a space, or at a blank line.
SENTENCE_END = re.compile(
    r"(?<=[.!?…])\s+|(?<=[.!?…][\"'”’)\]])\s+|\n\s*\n"
)


def split_sentences(text):
    return [s.strip() for s in SENTENCE_END.split(text) if s and s.strip()]


def trim_lead(samples, rate, threshold=0.01, keep=0.01):
    """Drops the near-silence voices start with, but `keep` seconds of it."""
    start = next(
        (i for i, x in enumerate(samples) if abs(x) > threshold), len(samples)
    )
    return samples[max(0, start - int(keep * rate)):]


class Item:
    def __init__(self, ident, text, voice, speed, tag, urgent, now):
        self.id = ident
        self.text = text
        self.sentences = split_sentences(text) or [text.strip()]
        self.voice = voice
        self.speed = speed
        self.tag = tag
        self.urgent = urgent
        self.now = now
        self.cursor = 0
        self.interrupt = None
        self.added = time.monotonic()

    def info(self, state):
        return {
            "id": self.id,
            "state": state,
            "voice": self.voice,
            "tag": self.tag,
            "urgent": self.urgent,
            "sentence": self.cursor,
            "sentences": len(self.sentences),
            "text": self.text,
        }


class Queue:
    """What to speak next. Pure state, guarded by the daemon's lock.

    `items` is in speaking order and holds the playing item too, so one held
    or interrupted mid-way keeps its place and its sentence cursor.
    """

    def __init__(self):
        self.items = []
        self.playing = None
        self.paused = False
        self.next_id = 1

    def add(self, text, voice=None, speed=1.0, tag=None, replace=False,
            urgent=False, now=False):
        if voice is None:
            voice = "alert" if len(split_sentences(text)) <= 1 else "read"
        item = Item(self.next_id, text, voice, speed, tag, urgent, now)
        self.next_id += 1
        if replace and tag is not None:
            self.items = [
                i for i in self.items if i.tag != tag or i is self.playing
            ]
        if now:
            self.items.insert(0, item)
        elif urgent:
            # Behind other urgent and --now items, ahead of the rest.
            at = next(
                (n for n, i in enumerate(self.items)
                 if not (i.urgent or i.now)),
                len(self.items),
            )
            self.items.insert(at, item)
        else:
            self.items.append(item)
        return item

    def eligible(self, item, held):
        if item.urgent:
            return True
        if held:
            return False
        return item.now or not self.paused

    def next(self, held):
        return next((i for i in self.items if self.eligible(i, held)), None)

    def remove(self, item):
        if item in self.items:
            self.items.remove(item)

    def started(self):
        """The item --stop acts on: the playing one, else one cut off mid-way."""
        if self.playing is not None:
            return self.playing
        return next((i for i in self.items if i.cursor > 0), None)

    def listing(self, held):
        out = []
        for item in self.items:
            if item is self.playing:
                state = "playing"
            elif self.eligible(item, held):
                state = "queued"
            else:
                state = "held"
            out.append(item.info(state))
        return out


class Voices:
    """The sherpa-onnx engines. Kokoro unloads after `idle` seconds unused."""

    def __init__(self, piper_dir, kokoro_dir, idle):
        import sherpa_onnx

        self.so = sherpa_onnx
        self.kokoro_dir = kokoro_dir
        self.idle = idle
        self.lock = threading.Lock()
        self.kokoro = None
        self.kokoro_used = 0.0
        model = next(f for f in os.listdir(piper_dir) if f.endswith(".onnx"))
        self.piper = self.make(
            sherpa_onnx.OfflineTtsModelConfig(
                vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                    model=os.path.join(piper_dir, model),
                    tokens=os.path.join(piper_dir, "tokens.txt"),
                    data_dir=os.path.join(piper_dir, "espeak-ng-data"),
                ),
                num_threads=PIPER_THREADS,
            )
        )
        threading.Thread(target=self.unloader, daemon=True).start()

    def make(self, model):
        return self.so.OfflineTts(
            self.so.OfflineTtsConfig(model=model, max_num_sentences=1)
        )

    def load_kokoro(self):
        d = self.kokoro_dir
        start = time.monotonic()
        self.kokoro = self.make(
            self.so.OfflineTtsModelConfig(
                kokoro=self.so.OfflineTtsKokoroModelConfig(
                    model=os.path.join(d, "model.onnx"),
                    voices=os.path.join(d, "voices.bin"),
                    tokens=os.path.join(d, "tokens.txt"),
                    data_dir=os.path.join(d, "espeak-ng-data"),
                ),
                num_threads=KOKORO_THREADS,
            )
        )
        log(f"kokoro loaded in {time.monotonic() - start:.2f}s")

    def synth(self, voice, text, speed):
        """Returns (sample rate, float32 PCM bytes)."""
        if voice == "alert":
            audio = self.piper.generate(text, sid=0, speed=speed)
        else:
            sid = 0 if voice == "read" else int(voice)
            with self.lock:
                if self.kokoro is None:
                    self.load_kokoro()
                engine = self.kokoro
                self.kokoro_used = time.monotonic()
            audio = engine.generate(text, sid=sid, speed=speed)
            with self.lock:
                self.kokoro_used = time.monotonic()
        rate = audio.sample_rate
        return rate, array("f", trim_lead(audio.samples, rate)).tobytes()

    def unloader(self):
        import ctypes
        import gc

        libc = ctypes.CDLL("libc.so.6")
        while True:
            time.sleep(min(30, self.idle))
            with self.lock:
                if self.kokoro is None:
                    continue
                if time.monotonic() - self.kokoro_used < self.idle:
                    continue
                self.kokoro = None
            gc.collect()
            # onnxruntime's arenas go back to glibc on free, not to the OS.
            libc.malloc_trim(0)
            log("kokoro unloaded")


class Player:
    """Plays one sentence at a time through pw-cat to the default sink."""

    def __init__(self, role=ROLE):
        self.role = role
        self.proc = None
        self.killed = False
        self.lock = threading.Lock()

    def play(self, rate, pcm, cancelled):
        """Blocks until played; False if kill() cut it off.

        `cancelled` is checked once the process exists, so a kill() that
        came before it isn't lost.
        """
        cmd = [
            "pw-cat", "--playback", "--raw", "--format", "f32",
            "--rate", str(rate), "--channels", "1",
            "--media-role", self.role, "--latency", LATENCY, "-",
        ]
        with self.lock:
            self.proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
            self.killed = cancelled()
            if self.killed:
                self.proc.kill()
        try:
            self.proc.communicate(pcm)
        except (BrokenPipeError, ValueError):
            pass
        with self.lock:
            killed = self.killed
            self.proc = None
        return not killed

    def kill(self):
        with self.lock:
            if self.proc is not None:
                self.killed = True
                self.proc.kill()


class Gate:
    """Whether non-urgent speech is held: DND on, or a game focused.

    DND is polled in a thread, so a lookup never waits on dms.
    """

    POLL = 1.0

    def __init__(self, dms, game_file):
        self.game_file = game_file
        self.dnd = False
        if dms:
            threading.Thread(target=self.poll, args=(dms,), daemon=True).start()

    def poll(self, dms):
        cmd = [dms, "ipc", "call", "notifications", "getDoNotDisturb"]
        while True:
            try:
                out = subprocess.run(
                    cmd, capture_output=True, text=True, timeout=2
                ).stdout.strip()
                self.dnd = out == "true"
            except (OSError, subprocess.SubprocessError):
                pass
            time.sleep(self.POLL)

    def __call__(self):
        if self.game_file and os.path.exists(self.game_file):
            return True
        return self.dnd


class Daemon:
    # How often held items re-check the gate.
    RECHECK = 2.0

    def __init__(self, voices, player, gate):
        self.voices = voices
        self.player = player
        self.gate = gate
        self.queue = Queue()
        self.cond = threading.Condition()
        # One synth thread per engine, so an alert never waits behind a Kokoro prefetch.
        self.pools = {"alert": ThreadPoolExecutor(1), "read": ThreadPoolExecutor(1)}

    # Requests

    def handle(self, req):
        cmd = req.get("cmd")
        with self.cond:
            q = self.queue
            if cmd == "say":
                item = q.add(
                    req["text"], req.get("voice"), req.get("speed", 1.0),
                    req.get("tag"), req.get("replace", False),
                    req.get("urgent", False), req.get("now", False),
                )
                playing = q.playing
                if (item.now and playing is not None
                        and q.eligible(item, self.gate())):
                    self.cut(playing, "requeue")
                self.cond.notify_all()
                return {"id": item.id}
            if cmd in ("stop", "skip"):
                item = q.started()
                if item is not None:
                    q.remove(item)
                    self.cut(item, "drop")
                self.cond.notify_all()
                return {"stopped": item.id if item else None}
            if cmd == "clear":
                n = len(q.items)
                for item in q.items:
                    self.cut(item, "drop")
                q.items = []
                self.cond.notify_all()
                return {"cleared": n}
            if cmd == "pause":
                q.paused = True
                playing = q.playing
                if playing is not None and not (playing.urgent or playing.now):
                    self.cut(playing, "requeue")
                return {"paused": True}
            if cmd == "resume":
                q.paused = False
                self.cond.notify_all()
                return {"paused": False}
            if cmd == "list":
                return {"paused": q.paused, "items": q.listing(self.gate())}
        return {"error": f"unknown command {cmd!r}"}

    def cut(self, item, reason):
        """Interrupt item if it is playing. Caller holds the lock."""
        if item is self.queue.playing:
            item.interrupt = reason
            self.player.kill()

    # Worker

    def take(self):
        with self.cond:
            while True:
                item = self.queue.next(self.gate())
                if item is not None:
                    item.interrupt = None
                    self.queue.playing = item
                    return item
                waiting = bool(self.queue.items)
                self.cond.wait(self.RECHECK if waiting else None)

    def synth(self, item, n):
        pool = self.pools["alert" if item.voice == "alert" else "read"]
        return pool.submit(
            self.voices.synth, item.voice, item.sentences[n], item.speed
        )

    def speak(self, item):
        pending = self.synth(item, item.cursor)
        try:
            while True:
                rate, pcm = pending.result()
                nxt = item.cursor + 1
                pending = None
                if nxt < len(item.sentences):
                    pending = self.synth(item, nxt)
                if not self.play(item, rate, pcm):
                    return
        finally:
            # A prefetch not yet started is dropped with its item.
            if pending is not None:
                pending.cancel()

    def play(self, item, rate, pcm):
        """Plays one sentence; False when the item stops here."""
        if item.added is not None:
            wait = time.monotonic() - item.added
            log(f"item {item.id} ({item.voice}): first audio in {wait:.2f}s")
            item.added = None
        if not self.player.play(rate, pcm, lambda: item.interrupt):
            return False
        with self.cond:
            if item.interrupt:
                return False
            item.cursor += 1
            if item.cursor == len(item.sentences):
                return False
            if not self.queue.eligible(item, self.gate()):
                item.interrupt = "requeue"
                return False
        return True

    def finish(self, item):
        with self.cond:
            self.queue.playing = None
            # A cut-off item ("requeue") keeps its place and sentence cursor.
            if item.interrupt is None or item.interrupt == "drop":
                self.queue.remove(item)
            item.interrupt = None
            self.cond.notify_all()

    def run(self):
        while True:
            item = self.take()
            try:
                self.speak(item)
            except Exception as err:  # a bad item must not stop the queue
                log(f"item {item.id}: {err!r}")
                item.interrupt = "drop"
            self.finish(item)

    def serve(self, path):
        daemon = self

        class Handler(socketserver.StreamRequestHandler):
            def handle(self):
                try:
                    req = json.loads(self.rfile.readline())
                    resp = daemon.handle(req)
                except (ValueError, KeyError, TypeError) as err:
                    resp = {"error": repr(err)}
                self.wfile.write((json.dumps(resp) + "\n").encode())

        if os.path.exists(path):
            os.unlink(path)
        server = socketserver.ThreadingUnixStreamServer(path, Handler)
        server.daemon_threads = True
        threading.Thread(target=self.run, daemon=True).start()
        log(f"listening on {path}")
        server.serve_forever()


def request(req, wait=5.0):
    path = socket_path()
    deadline = time.monotonic() + wait
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(path)
                sock.sendall((json.dumps(req) + "\n").encode())
                data = sock.makefile("r").readline()
            break
        except (FileNotFoundError, ConnectionRefusedError) as err:
            # The daemon is starting or restarting; give it a moment.
            if time.monotonic() > deadline:
                sys.exit(f"say: daemon not reachable at {path}: {err}")
            time.sleep(0.1)
        except OSError as err:
            sys.exit(f"say: daemon not reachable at {path}: {err}")
    resp = json.loads(data)
    if "error" in resp:
        sys.exit(f"say: {resp['error']}")
    return resp


def voice_arg(value):
    if value in ("alert", "read") or value.isdigit():
        return value
    raise argparse.ArgumentTypeError("alert, read or a Kokoro speaker id")


def main(argv=None):
    p = argparse.ArgumentParser(
        prog="say", description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument("text", nargs="*")
    p.add_argument("-v", "--voice", type=voice_arg)
    p.add_argument("-n", "--now", action="store_true")
    p.add_argument("-u", "--urgent", action="store_true")
    p.add_argument("-t", "--tag")
    p.add_argument("-r", "--replace", action="store_true")
    p.add_argument("-s", "--speed", type=float, default=1.0)
    control = p.add_mutually_exclusive_group()
    for name in ("stop", "skip", "clear", "pause", "resume", "list"):
        control.add_argument(f"--{name}", dest="cmd", action="store_const",
                             const=name)
    p.add_argument("--json", action="store_true")
    daemon = p.add_argument_group("daemon")
    daemon.add_argument("--daemon", action="store_true")
    daemon.add_argument("--piper", default=os.environ.get("SAY_PIPER"))
    daemon.add_argument("--kokoro", default=os.environ.get("SAY_KOKORO"))
    daemon.add_argument("--kokoro-idle", type=float, default=300)
    daemon.add_argument("--dms")
    daemon.add_argument("--game-file")
    args = p.parse_args(argv)

    if args.daemon:
        voices = Voices(args.piper, args.kokoro, args.kokoro_idle)
        Daemon(voices, Player(), Gate(args.dms, args.game_file)).serve(
            socket_path()
        )
        return
    if args.replace and not args.tag:
        p.error("--replace needs --tag")
    if args.cmd:
        resp = request({"cmd": args.cmd})
        if args.cmd == "list":
            if args.json:
                print(json.dumps(resp))
            else:
                if resp["paused"]:
                    print("(paused)")
                for i in resp["items"]:
                    tag = f" [{i['tag']}]" if i["tag"] else ""
                    print(f"{i['id']} {i['state']} {i['voice']}{tag}: "
                          f"{i['text'][:70]}")
        return
    text = " ".join(args.text)
    if not text:
        if sys.stdin.isatty():
            p.error("no text given and stdin is a terminal")
        text = sys.stdin.read()
    if not text.strip():
        return
    resp = request({
        "cmd": "say", "text": text, "voice": args.voice, "speed": args.speed,
        "tag": args.tag, "replace": args.replace, "urgent": args.urgent,
        "now": args.now,
    })
    if args.json:
        print(json.dumps(resp))


if __name__ == "__main__":
    main()
