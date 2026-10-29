"""Test the kanata keymap in kanata's simulator.

With no --fuzz, runs every case in the keymap's tests/*.sim files and exits
non-zero when one fails. Naming a file (`mods`) or one case in it
(`mods:19`, its input line) runs only those, with the simulator's timeline.
A case is an input line, then the output it must give:

    # Opposite-hand roll at 120 wpm.
    type: for wpm=120 hold=150
    out: for

`type:` synthesises a roll (default 90 wpm, each key held 100 ms) after an
idle pause; `in:` takes raw simulator events instead. Output is the typed
text, with chords and lone modifiers as <C-c> or <M-S>.

--fuzz types word lists as continuous text at several speeds, with seeded
random timing, and reports the words that came out wrong by bigram.
"""

import argparse
import difflib
import random
import shlex
import string
import subprocess
import sys
import tempfile
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

SIM = @sim@  # noqa: E501
DEFCFG = @defcfg@
KEYMAP_DIR = @keymapDir@  # noqa: E501
WORD_LISTS = @wordLists@  # noqa: E501

IDLE = 500
SETTLE = 1000
OPTIONS = {"wpm", "hold"}

MODS = {
    "LCtrl": "C", "RCtrl": "C",
    "LAlt": "A", "RAlt": "A",
    "LGui": "M", "RGui": "M",
    "LShift": "S", "RShift": "S",
}
MOD_ORDER = "CAMS"

# Kanata output name: (plain, shifted).
CHARS = {
    "SColon": (";", ":"), "Quote": ("'", '"'), "Comma": (",", "<"),
    "Dot": (".", ">"), "Slash": ("/", "?"), "Minus": ("-", "_"),
    "Equal": ("=", "+"), "LBracket": ("[", "{"), "RBracket": ("]", "}"),
    "Bslash": ("\\", "|"), "Grave": ("`", "~"), "Space": (" ", " "),
}
CHARS.update(
    {f"Kb{d}": (d, s) for d, s in zip("1234567890", "!@#$%^&*()")}
)
CHARS.update({c.upper(): (c, c.upper()) for c in string.ascii_lowercase})

# Typed character: kanata input name.
KEYS = {c: c for c in string.ascii_lowercase + "1234567890;',./-=[]"}
KEYS.update({" ": "spc", "\\": "\\", "`": "grv"})


def config(tmp, keymap_dir):
    path = Path(tmp) / "keymap-test.kbd"
    path.write_text(
        f"(defcfg\n  {DEFCFG})\n\n(include {keymap_dir}/keymap.kbd)\n"
    )
    return path


def simulate(cfg, events, tmp, name):
    sim = Path(tmp) / f"{name}.txt"
    sim.write_text(" ".join(events))
    run = subprocess.run(
        [SIM, "-c", str(cfg), "-s", str(sim)],
        capture_output=True, text=True,
    )
    if run.returncode != 0:
        sys.exit(f"simulator failed:\n{run.stderr}")
    out = [line[4:] for line in run.stdout.splitlines()
           if line.startswith("out:")]
    return out, run.stderr


def chord(mods, name=None):
    parts = sorted(mods, key=MOD_ORDER.index) + ([name] if name else [])
    return "<" + "-".join(parts) + ">"


def render(out):
    """The text an application would see from kanata's output events."""
    text = []
    held = set()
    group = set()
    used = False
    for event in out:
        down, name = event[0] == "↓", event[1:]
        if name in MODS:
            if down:
                held.add(name)
                group.add(MODS[name])
            else:
                held.discard(name)
                if not held:
                    if not used:
                        text.append(chord(group))
                    group = set()
                    used = False
            continue
        if not down:
            continue
        mods = {MODS[m] for m in held}
        used = used or bool(held)
        if mods <= {"S"} and name in CHARS:
            text.append(CHARS[name][bool(mods)])
        else:
            key = CHARS[name][0] if name in CHARS else name.lower()
            text.append(chord(mods, "spc" if key == " " else key))
    return "".join(text)


def roll(timed):
    """Simulator events from (press ms, release ms, key) triples."""
    edges = []
    for press, release, key in timed:
        edges.append((press, "d", key))
        edges.append((release, "u", key))
    edges.sort(key=lambda e: (e[0], e[1] == "d"))
    events = [f"t:{IDLE}"]
    now = 0
    for at, kind, key in edges:
        if at > now:
            events.append(f"t:{at - now}")
            now = at
        events.append(f"{kind}:{key}")
    events.append(f"t:{SETTLE}")
    return events


def interval(wpm):
    """Milliseconds between presses, at five characters a word."""
    return 60000 / (5 * wpm)


def synthesise(text, wpm, hold):
    timed = []
    for i, c in enumerate(text):
        press = round(i * interval(wpm))
        timed.append((press, press + hold, KEYS[c]))
    return roll(separate_repeats(timed))


def separate_repeats(timed):
    """Release a key before its next press, as a finger has to."""
    fixed = []
    for i, (press, release, key) in enumerate(timed):
        for later, _, other in timed[i + 1:]:
            if other == key:
                release = min(release, later - 1)
                break
        fixed.append((press, max(release, press + 1), key))
    return fixed


def parse_cases(path):
    cases = []
    pending = None
    for n, line in enumerate(path.read_text().splitlines(), 1):
        line = line.strip()
        where = f"{path.name}:{n}"
        if not line or line.startswith("#"):
            continue
        kind, _, rest = line.partition(":")
        rest = rest.strip()
        if kind in ("in", "type"):
            if pending:
                sys.exit(f"{where}: {pending[0]} has no out: line")
            pending = (where, kind, rest)
        elif kind == "out":
            if not pending:
                sys.exit(f"{where}: out: without an input line")
            cases.append((*pending, rest))
            pending = None
        else:
            sys.exit(f"{where}: unknown line kind {kind!r}")
    if pending:
        sys.exit(f"{pending[0]}: no out: line")
    return cases


def is_option(word):
    name, eq, value = word.partition("=")
    return name in OPTIONS and eq and value.isdigit()


def case_events(where, kind, spec):
    if kind == "in":
        return [f"t:{IDLE}", *spec.split(), f"t:{SETTLE}"]
    words = shlex.split(spec)
    opts = dict(w.split("=", 1) for w in words if is_option(w))
    text = " ".join(w for w in words if not is_option(w))
    if bad := set(text) - set(KEYS):
        sys.exit(f"{where}: can't type {''.join(sorted(bad))!r}")
    return synthesise(
        text, int(opts.get("wpm", 90)), int(opts.get("hold", 100))
    )


def timeline(stderr):
    lines = stderr.splitlines()
    start = next(
        (i for i, line in enumerate(lines) if line.startswith("🕐")),
        len(lines),
    )
    return "\n".join(lines[start:])


def run_cases(keymap_dir, names):
    files = sorted((keymap_dir / "tests").glob("*.sim"))
    picked = {}
    for name in names:
        stem, _, line = name.partition(":")
        picked.setdefault(stem, set()).add(line)
    if names:
        files = [f for f in files if f.stem in picked]
        if missing := set(picked) - {f.stem for f in files}:
            sys.exit(f"no such case file: {', '.join(sorted(missing))}")
    if not files:
        sys.exit(f"no case files in {keymap_dir}/tests")
    failed = total = 0
    with tempfile.TemporaryDirectory() as tmp:
        cfg = config(tmp, keymap_dir)
        for f in files:
            for i, (where, kind, spec, want) in enumerate(parse_cases(f)):
                lines = picked.get(f.stem, {""})
                if "" not in lines and where.split(":")[1] not in lines:
                    continue
                total += 1
                events = case_events(where, kind, spec)
                out, stderr = simulate(cfg, events, tmp, f"{f.stem}-{i}")
                got = render(out)
                ok = got == want
                failed += not ok
                if names or not ok:
                    mark = "ok  " if ok else "FAIL"
                    print(f"{mark} {where}  {kind}: {spec}")
                    print(f"     want {want!r}, got {got!r}")
                if names:
                    print("     " + " ".join(events))
                    print(timeline(stderr) + "\n")
    if not total:
        sys.exit(f"no case starts on the line given: {' '.join(names)}")
    print(f"{total - failed}/{total} cases pass")
    return 1 if failed else 0


def load_words(paths):
    words = set()
    for path in paths:
        for word in Path(path).read_text().split():
            word = word.lower()
            if set(word) <= set(KEYS) - {" "}:
                words.add(word)
    return sorted(words)


def fuzz_events(words, wpm, rng):
    timed = []
    now = 0.0
    for c in " ".join(words) + " ":
        press = round(now)
        hold = round(rng.uniform(60, 140))
        timed.append((press, press + hold, KEYS[c]))
        now += interval(wpm) * rng.uniform(0.6, 1.4)
    return roll(separate_repeats(timed))


def mismatches(want, got):
    """(wanted, got) word runs where the output differs."""
    pairs = []
    matcher = difflib.SequenceMatcher(a=want, b=got, autojunk=False)
    for op, a1, a2, b1, b2 in matcher.get_opcodes():
        if op != "equal":
            pairs.append((" ".join(want[a1:a2]), " ".join(got[b1:b2])))
    return pairs


def bigram(want, got):
    """The first wrong key and the key typed before it."""
    want, got = " " + want, " " + got
    i = next(
        (i for i, (a, b) in enumerate(zip(want, got)) if a != b),
        min(len(want), len(got)),
    )
    return want[max(i - 1, 0):i + 1].replace(" ", "␣")


def fuzz(keymap_dir, paths, speeds, seed, batch):
    words = load_words(paths)
    if not words:
        sys.exit("no typeable words in the word lists")
    print(f"seed {seed}, {len(words)} words, speeds {speeds} wpm")
    jobs = []
    for wpm in speeds:
        rng = random.Random(f"{seed}-{wpm}")
        order = rng.sample(words, len(words))
        for start in range(0, len(order), batch):
            chunk = order[start:start + batch]
            jobs.append((wpm, chunk, fuzz_events(chunk, wpm, rng)))
    with tempfile.TemporaryDirectory() as tmp:
        cfg = config(tmp, keymap_dir)
        with ThreadPoolExecutor() as pool:
            outs = list(pool.map(
                lambda n, job: simulate(cfg, job[2], tmp, f"fuzz-{n}")[0],
                range(len(jobs)), jobs,
            ))
    wrong = defaultdict(list)
    per_speed = defaultdict(int)
    for (wpm, chunk, _), out in zip(jobs, outs):
        typed = render(out).split(" ")
        if typed[-1] == "":
            typed.pop()
        for want, got in mismatches(chunk, typed):
            per_speed[wpm] += 1
            wrong[bigram(want, got)].append((wpm, want, got))
    for wpm in speeds:
        print(f"  {wpm:>3} wpm: {per_speed[wpm]} wrong")
    if not wrong:
        return 0
    print("by bigram:")
    for gram, cases in sorted(wrong.items(), key=lambda kv: -len(kv[1])):
        shown = ", ".join(
            f"{w!r}→{g!r} @{wpm}" for wpm, w, g in sorted(cases)[:4]
        )
        print(f"  {gram:<4}{len(cases):>4}  {shown}")
    return 1


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("cases", nargs="*", help="case files to run alone")
    parser.add_argument("--keymap", type=Path, default=Path(KEYMAP_DIR))
    parser.add_argument("--fuzz", action="store_true")
    parser.add_argument("--words", nargs="+")
    parser.add_argument(
        "--wpm", type=lambda s: [int(w) for w in s.split(",")],
        default=[60, 90, 120, 150],
    )
    parser.add_argument("--seed", type=int)
    parser.add_argument("--batch", type=int, default=100)
    args = parser.parse_args()
    if args.fuzz:
        seed = args.seed if args.seed is not None else random.randrange(10**6)
        words = args.words or [
            *WORD_LISTS, args.keymap / "tests" / "hrm-words.txt"
        ]
        words = [w for w in words if Path(w).exists()]
        sys.exit(fuzz(args.keymap, words, args.wpm, seed, args.batch))
    sys.exit(run_cases(args.keymap, args.cases))


main()
