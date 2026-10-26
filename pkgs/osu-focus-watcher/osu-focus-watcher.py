"""Switch every kanata instance to passthrough while an osu window has focus.

Reads niri's event stream for focus changes and keeps a TCP connection to
each kanata instance. On losing focus it restores the layer the instance had
before osu took it, so a manual passthrough or Fn Lock survives a session.
"""

import argparse
import json
import socket
import subprocess
import threading
import time

PASSTHROUGH = "passthrough"
lock = threading.Lock()


def log(*parts):
    print(*parts, flush=True)


class Instance:
    """One kanata TCP server, reconnected for as long as the watcher runs."""

    def __init__(self, port, watcher):
        self.port = port
        self.watcher = watcher
        self.sock = None
        self.current = None
        self.saved = None

    def send(self, message):
        try:
            self.sock.sendall((json.dumps(message) + "\n").encode())
        except OSError as err:
            log(f"kanata:{self.port}: send failed: {err}")

    def change_layer(self, layer):
        self.send({"ChangeLayer": {"new": layer}})

    def enter(self):
        if self.sock is not None:
            self.saved = self.current
            self.change_layer(PASSTHROUGH)

    def leave(self):
        if self.sock is not None and self.saved is not None:
            self.change_layer(self.saved)
        self.saved = None

    def handle(self, message, first):
        if "LayerChange" in message:
            self.current = message["LayerChange"]["new"]
            # kanata greets each connection with its current layer.
            if first and self.watcher.osu_focused:
                self.saved = self.current
                self.change_layer(PASSTHROUGH)
        elif "ConfigFileReload" in message:
            # A reload rebuilds the layout on its first layer, unannounced.
            self.send({"RequestCurrentLayerName": {}})
        elif "CurrentLayerName" in message:
            self.current = message["CurrentLayerName"]["name"]
            if self.watcher.osu_focused and self.current != PASSTHROUGH:
                self.change_layer(PASSTHROUGH)

    def run(self):
        delay = 0.1
        while True:
            try:
                sock = socket.create_connection(("127.0.0.1", self.port))
            except OSError:
                time.sleep(delay)
                delay = min(delay * 2, 1.0)
                continue
            delay = 0.1
            log(f"kanata:{self.port}: connected")
            with lock:
                self.sock = sock
            first = True
            try:
                for line in sock.makefile("r", encoding="utf-8"):
                    with lock:
                        self.handle(json.loads(line), first)
                    first = False
            except (OSError, ValueError) as err:
                log(f"kanata:{self.port}: {err}")
            with lock:
                self.sock = None
                self.current = None
            sock.close()
            log(f"kanata:{self.port}: disconnected")


class Watcher:
    """Tracks niri's focused window and drives every instance from it."""

    def __init__(self, app_ids, ports):
        self.app_ids = set(app_ids)
        self.instances = [Instance(port, self) for port in ports]
        self.windows = {}
        self.focused = None
        self.osu_focused = False

    def update(self, event):
        if "WindowsChanged" in event:
            windows = event["WindowsChanged"]["windows"]
            self.windows = {w["id"]: w["app_id"] for w in windows}
            self.focused = next(
                (w["id"] for w in windows if w["is_focused"]), None
            )
        elif "WindowOpenedOrChanged" in event:
            window = event["WindowOpenedOrChanged"]["window"]
            self.windows[window["id"]] = window["app_id"]
            if window["is_focused"]:
                self.focused = window["id"]
        elif "WindowClosed" in event:
            self.windows.pop(event["WindowClosed"]["id"], None)
        elif "WindowFocusChanged" in event:
            self.focused = event["WindowFocusChanged"]["id"]
        else:
            return
        osu = self.windows.get(self.focused) in self.app_ids
        if osu != self.osu_focused:
            self.osu_focused = osu
            log("osu focused" if osu else "osu unfocused")
            for instance in self.instances:
                if osu:
                    instance.enter()
                else:
                    instance.leave()

    def run(self, niri):
        for instance in self.instances:
            threading.Thread(target=instance.run, daemon=True).start()
        while True:
            cmd = [niri, "msg", "--json", "event-stream"]
            with subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True) as p:
                for line in p.stdout:
                    try:
                        event = json.loads(line)
                    except ValueError:
                        continue
                    with lock:
                        self.update(event)
            log("niri event stream ended; retrying")
            time.sleep(1)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--niri", default="niri")
    parser.add_argument("--app-id", action="append", required=True)
    parser.add_argument("--port", action="append", type=int, required=True)
    args = parser.parse_args()
    Watcher(args.app_id, args.port).run(args.niri)


if __name__ == "__main__":
    main()
