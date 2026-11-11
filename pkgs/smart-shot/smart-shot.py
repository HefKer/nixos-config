"""Click an object on screen and copy a screenshot cropped to it.

    smart-shot           capture: click a picture, table, code block...; the crop goes to the clipboard
    smart-shot flag      label the last capture as a test case: right, the region you wanted, or nothing
    smart-shot test      rerun every case (or the named ones) through the current code and score it

Code finds candidate rectangles around the click from long straight edges, so their edges are
pixel-exact, and Jev judges whether each outlined candidate is one whole item; the best one
wins. When none passes, Jev's Box over the marked screen is the fallback, snapped to the
nearest edges. Every capture is kept in $XDG_STATE_HOME/smart-shot/runs/ (the unmarked screen,
the click, what was sent and answered), and flagged cases in $XDG_DATA_HOME/smart-shot/cases/.
"""

import argparse
import concurrent.futures
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid

import numpy as np
from PIL import Image, ImageDraw

# Tuning: everything prototyping is expected to change lives here.
ITEM = "picture, table, code block, card, panel or similar boxed item"
CANDIDATE_QUESTION = (
    "Does the green rectangle in {view} go exactly around one " + ITEM + ", rather than around part of one or around several?"
)
PRESENT_QUESTION = "Is the red marker in {screen} on a " + ITEM + "?"
BOX_QUESTION = "the " + ITEM + " the red marker is on in {screen}"
CANDIDATE_YES = 0.7  # the best candidate at or above this wins
PRESENT_YES = 0.7  # with no candidate passing, the Box is used only when this noul reads yes
MAX_CANDIDATES = 8  # smallest first; each one is a question with its own image
EDGES = {
    "contrast": 24,  # summed RGB difference between neighbouring pixels that counts as an edge
    "min_run": 40,  # px: shortest edge run that proposes a line
    "gap": 2,  # px: breaks in a run up to this long are bridged (wider ones turn lines of text into lines)
    "coverage": 0.8,  # fraction of a side that must be edge
    "ends": 0.15,  # ...and each end of a side, this share of its length, must be half edge: no borrowed lines
    "per_side": 30,  # nearest lines tried on each side of the click
    "overhang": 8,  # px past each corner where a side's line must stop (a grid line doesn't); short, as stacked items line up
    "same": 4,  # px: rectangles closer than this on every side are one candidate
    "max_share": 0.9,  # rectangles covering more of the screen than this are dropped: that's the whole screen
}
SNAP_PX = 12  # a Box edge moves to a strong edge line this close
BOX_PAD_PX = 6  # added around a Box crop, whose edges aren't pixel-exact; candidates get none
SECOND_PASS_BELOW = 0.5  # re-ask the Box on a full-resolution crop when it spans less than this of both sides
SECOND_PASS_MARGIN = 0.5  # that crop: the box grown by this fraction of its size per side
MARKER = {"radius": 14, "width": 4, "colour": (255, 0, 0)}
OUTLINE = {"width": 3, "colour": (0, 255, 0), "context": 0.15, "min_context": 40, "max_side": 768}
PASS_IOU = 0.9  # smart-shot test: overlap with the expected region that counts as a pass
KEEP_RUNS = 40

# The API's image limits; it never resizes.
MAX_SIDE = 1568
MIN_SIDE = 280

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "smart-shot")
RUNS = os.path.join(STATE, "runs")
CASES = os.path.join(os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share"), "smart-shot", "cases")


class Failure(Exception):
    pass


def notify(summary, body=""):
    subprocess.run(["notify-send", "-a", "smart-shot", summary, body], check=False)


# Candidates ------------------------------------------------------------------------------


class EdgeMap:
    """Horizontal and vertical edges, with prefix sums for the share of edge along any segment.

    h[y, x] is an edge between rows y-1 and y, so lines run from 0 to the height inclusive and a
    rectangle (l, t, r, b) is exactly what PIL's crop takes. The screen border counts as an edge.
    """

    def __init__(self, image):
        a = np.asarray(image, dtype=np.int16)
        height, width = a.shape[:2]
        self.width, self.height = width, height
        self.h = np.ones((height + 1, width), bool)
        self.h[1:height] = np.abs(a[1:] - a[:-1]).sum(2) > EDGES["contrast"]
        self.v = np.ones((height, width + 1), bool)
        self.v[:, 1:width] = np.abs(a[:, 1:] - a[:, :-1]).sum(2) > EDGES["contrast"]
        self.hsum = np.concatenate((np.zeros((height + 1, 1), int), np.cumsum(self.h, 1)), 1)
        self.vsum = np.concatenate((np.zeros((1, width + 1), int), np.cumsum(self.v, 0)), 0)

    def hcover(self, y, x0, x1):
        x0, x1 = max(0, x0), min(self.width, x1)
        return (self.hsum[y, x1] - self.hsum[y, x0]) / (x1 - x0) if x1 > x0 else None

    def vcover(self, x, y0, y1):
        y0, y1 = max(0, y0), min(self.height, y1)
        return (self.vsum[y1, x] - self.vsum[y0, x]) / (y1 - y0) if y1 > y0 else None


def lines_through(edges, along):
    """Indices of the lines (rows of `edges`) whose edge runs, gaps bridged, pass position `along`."""
    found = []
    for index, line in enumerate(edges):
        hits = np.flatnonzero(line)
        if not hits.size:
            continue
        breaks = np.flatnonzero(np.diff(hits) > EDGES["gap"] + 1)
        starts = np.concatenate(([hits[0]], hits[breaks + 1]))
        ends = np.concatenate((hits[breaks], [hits[-1]])) + 1
        if any(s <= along < e and e - s >= EDGES["min_run"] for s, e in zip(starts, ends)):
            found.append(index)
    return found


def stops(before, after):
    """A side's line stops at its corners: little edge just past either end, or the screen ends."""
    return all(c is None or c < 0.5 for c in (before, after))


def area(rect):
    return (rect[2] - rect[0]) * (rect[3] - rect[1])


def candidates(edges, click):
    """Rectangles around `click` whose four sides are mostly edge and stop at the corners, smallest first."""
    cx, cy = int(click[0]), int(click[1])
    rows = lines_through(edges.h, cx)
    cols = lines_through(edges.v.T, cy)
    k, cover, over, corner = EDGES["per_side"], EDGES["coverage"], EDGES["overhang"], 3
    tops = sorted((y for y in rows if y <= cy), key=lambda y: cy - y)[:k]
    bottoms = sorted((y for y in rows if y > cy), key=lambda y: y - cy)[:k]
    lefts = sorted((x for x in cols if x <= cx), key=lambda x: cx - x)[:k]
    rights = sorted((x for x in cols if x > cx), key=lambda x: x - cx)[:k]

    def anchored(cover_of, low, high):
        end = max(1, round(EDGES["ends"] * (high - low)))
        return cover_of(low, high) >= cover and cover_of(low, low + end) >= 0.5 and cover_of(high - end, high) >= 0.5

    def side_h(y, l, r):
        if not anchored(lambda lo, hi: edges.hcover(y, lo, hi), l, r):
            return False
        if y in (0, edges.height):
            return True
        before = edges.hcover(y, l - corner - over, l - corner)
        return stops(before, edges.hcover(y, r + corner, r + corner + over))

    def side_v(x, t, b):
        if not anchored(lambda lo, hi: edges.vcover(x, lo, hi), t, b):
            return False
        if x in (0, edges.width):
            return True
        before = edges.vcover(x, t - corner - over, t - corner)
        return stops(before, edges.vcover(x, b + corner, b + corner + over))

    found = [
        (l, t, r, b)
        for t in tops
        for b in bottoms
        for l in lefts
        if side_v(l, t, b)
        for r in rights
        if side_v(r, t, b) and side_h(t, l, r) and side_h(b, l, r)
    ]
    # A border line makes two edges; of near-identical rectangles keep the outer, border included.
    kept = []
    screen = edges.width * edges.height
    for rect in sorted((f for f in found if area(f) <= EDGES["max_share"] * screen), key=area, reverse=True):
        if all(max(abs(p - q) for p, q in zip(rect, other)) > EDGES["same"] for other in kept):
            kept.append(rect)
    return sorted(kept, key=area)


def snap(box, edges):
    """Each side of a Box moved to the strongest edge line within SNAP_PX along the box's span."""
    l, t, r, b = (round(v) for v in box)

    def best(position, limit, cover):
        options = []
        for p in range(max(0, position - SNAP_PX), min(limit, position + SNAP_PX) + 1):
            c = cover(p)
            if c is not None and c >= 0.5:
                options.append((c, -abs(p - position), p))
        return max(options)[2] if options else position

    snapped = (
        best(l, edges.width, lambda x: edges.vcover(x, t, b)),
        best(t, edges.height, lambda y: edges.hcover(y, l, r)),
        best(r, edges.width, lambda x: edges.vcover(x, t, b)),
        best(b, edges.height, lambda y: edges.hcover(y, l, r)),
    )
    return snapped if snapped[0] < snapped[2] and snapped[1] < snapped[3] else (l, t, r, b)


# Asking Jev ------------------------------------------------------------------------------


def fit(image, max_side=MAX_SIDE):
    """`image` inside the API's limits, and the scale applied; padding keeps fractions mappable."""
    scale = min(1.0, max_side / image.width, max_side / image.height)
    if scale < 1:
        image = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    if min(image.size) < MIN_SIDE:
        padded = Image.new("RGB", (max(image.width, MIN_SIDE), max(image.height, MIN_SIDE)), (128, 128, 128))
        padded.paste(image)
        image = padded
    return image, scale


def marked(shot, region, click):
    """`region` of `shot`, fitted, with the marker at `click`."""
    image, scale = fit(shot.crop(region))
    cx, cy = (click[0] - region[0]) * scale, (click[1] - region[1]) * scale
    draw = ImageDraw.Draw(image)
    r, colour = MARKER["radius"], MARKER["colour"]
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=colour, width=MARKER["width"])
    draw.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=colour)
    return image, scale


def outlined(shot, rect):
    """The candidate with some of its surroundings, outlined just outside its edges."""
    l, t, r, b = rect
    margin = max(OUTLINE["min_context"], round(OUTLINE["context"] * max(r - l, b - t)))
    view = (max(0, l - margin), max(0, t - margin), min(shot.width, r + margin), min(shot.height, b + margin))
    image = shot.crop(view)
    w = OUTLINE["width"]
    outline = (l - view[0] - w, t - view[1] - w, r - view[0] + w - 1, b - view[1] + w - 1)
    ImageDraw.Draw(image).rectangle(outline, outline=OUTLINE["colour"], width=w)
    return fit(image, OUTLINE["max_side"])[0]


class Request:
    """One /v1/systemone request, its images saved in `workdir`, sent through `jev ask`."""

    def __init__(self, workdir, tag):
        self.workdir, self.tag = workdir, tag
        self.assets, self.files, self.questions = {}, {}, {}

    def image(self, name, image):
        ref = f"{name}-{uuid.uuid4().hex[:8]}"
        path = os.path.join(self.workdir, f"{self.tag}-{name}.png")
        image.save(path)
        self.assets[ref] = {"type": "image", "part": name}
        self.files[name] = path
        return ref

    def ask(self):
        body = {"state": {}, "assets": self.assets, "questions": self.questions}
        with open(os.path.join(self.workdir, f"{self.tag}-request.json"), "w", encoding="utf-8") as handle:
            json.dump(body, handle, indent=2)
        command = ["jev", "ask"] + [f"--image={name}={path}" for name, path in self.files.items()]
        try:
            done = subprocess.run(command, input=json.dumps(body), capture_output=True, text=True, check=False)
        except OSError as error:
            raise Failure(f"can't run jev: {error.strerror}") from None
        if done.returncode:
            raise Failure(done.stderr.strip() or f"jev exited {done.returncode}")
        with open(os.path.join(self.workdir, f"{self.tag}-answer.json"), "w", encoding="utf-8") as handle:
            handle.write(done.stdout)
        return json.loads(done.stdout)["answers"]


def box_answer(answer, region, scale, sent):
    """A Box answer's fractions of the sent image, back in `shot` pixels."""
    edges = answer["box"]
    width, height = sent.width / scale, sent.height / scale
    return (
        region[0] + edges["left"] * width,
        region[1] + edges["top"] * height,
        region[0] + edges["right"] * width,
        region[1] + edges["bottom"] * height,
    )


def grow(region, size, bounds):
    """`region` widened about its centre to at least `size` per side, inside `bounds`."""
    out = []
    for low, high, limit in ((region[0], region[2], bounds[0]), (region[1], region[3], bounds[1])):
        short = max(0, min(size, limit) - (high - low))
        low, high = low - short / 2, high + short / 2
        if low < 0:
            low, high = 0, high - low
        if high > limit:
            low, high = max(0, low - (high - limit)), limit
        out.append((round(low), round(high)))
    (left, right), (top, bottom) = out
    return left, top, right, bottom


def refine(shot, box, click, workdir, report):
    """The Box asked again on a full-resolution crop around it; the first box if that fails."""
    box_w, box_h = box[2] - box[0], box[3] - box[1]
    mx, my = max(box_w * SECOND_PASS_MARGIN, 50), max(box_h * SECOND_PASS_MARGIN, 50)
    around = (min(box[0] - mx, click[0]), min(box[1] - my, click[1]), max(box[2] + mx, click[0]), max(box[3] + my, click[1]))
    region = grow(around, MIN_SIDE, shot.size)
    request = Request(workdir, "pass2")
    image, scale = marked(shot, region, click)
    request.questions["box"] = {"type": "box", "instructions": BOX_QUESTION.format(screen=request.image("screen", image))}
    try:
        box = box_answer(request.ask()["box"], region, scale, image)
        report["box2"] = [round(v, 1) for v in box]
    except Failure as error:
        report["box2_error"] = str(error)
    return box


def locate(shot, click, workdir):
    """The rectangle to copy, or None, and a report of how it was chosen."""
    edges = EdgeMap(shot)
    rects = candidates(edges, click)[:MAX_CANDIDATES]
    whole = (0, 0, shot.width, shot.height)
    request = Request(workdir, "pass1")
    screen, scale = marked(shot, whole, click)
    ref = request.image("screen", screen)
    request.questions["present"] = {"type": "noul", "instructions": PRESENT_QUESTION.format(screen=ref)}
    request.questions["box"] = {"type": "box", "instructions": BOX_QUESTION.format(screen=ref)}
    for i, rect in enumerate(rects):
        view = request.image(f"candidate{i}", outlined(shot, rect))
        request.questions[f"candidate{i}"] = {"type": "noul", "instructions": CANDIDATE_QUESTION.format(view=view)}
    answers = request.ask()

    scored = [(answers[f"candidate{i}"]["noul"], rect) for i, rect in enumerate(rects)]
    box = box_answer(answers["box"], whole, scale, screen)
    report = {
        "candidates": [{"rect": list(rect), "yes": round(p, 3)} for p, rect in scored],
        "present": round(answers["present"]["noul"], 3),
        "box": [round(v, 1) for v in box],
    }
    best = max(scored, default=None)
    if best and best[0] >= CANDIDATE_YES:
        return best[1], {**report, "chosen": "candidate"}
    if report["present"] < PRESENT_YES:
        return None, {**report, "chosen": "nothing"}
    small = box[2] - box[0] < SECOND_PASS_BELOW * shot.width and box[3] - box[1] < SECOND_PASS_BELOW * shot.height
    if scale < 1 and small:
        box = refine(shot, box, click, workdir, report)
    if box[2] - box[0] < 1 or box[3] - box[1] < 1:
        raise Failure(f"empty box {box}")
    l, t, r, b = snap(box, edges)
    pad = BOX_PAD_PX
    padded = (max(0, l - pad), max(0, t - pad), min(shot.width, r + pad), min(shot.height, b + pad))
    return padded, {**report, "chosen": "box"}


# Capture ---------------------------------------------------------------------------------


def capture_outputs(workdir):
    """{name: (logical, PNG path)} for every enabled output, captured before the click."""
    listing = subprocess.run(["niri", "msg", "--json", "outputs"], capture_output=True, text=True, check=True)
    shots = {}
    for name, output in json.loads(listing.stdout).items():
        if output.get("logical"):
            path = os.path.join(workdir, f"{name}.png")
            subprocess.run(["grim", "-o", name, path], check=True)
            shots[name] = (output["logical"], path)
    return shots


def pick_point():
    """The clicked point in global logical coordinates, or None when the pick is cancelled."""
    done = subprocess.run(["slurp", "-p", "-f", "%x %y"], capture_output=True, text=True, check=False)
    if done.returncode:
        return None
    x, y = done.stdout.split()
    return int(x), int(y)


def to_pixels(x, y, logical, ratio):
    return (x - logical["x"]) * ratio[0], (y - logical["y"]) * ratio[1]


def output_at(point, shots):
    for name, (logical, path) in shots.items():
        if logical["x"] <= point[0] < logical["x"] + logical["width"] and logical["y"] <= point[1] < logical["y"] + logical["height"]:
            return name, logical, path
    raise Failure("the click is on no output")


def prune():
    for old in sorted(os.listdir(RUNS))[:-KEEP_RUNS]:
        shutil.rmtree(os.path.join(RUNS, old), ignore_errors=True)


def capture():
    with tempfile.TemporaryDirectory(prefix="smart-shot-") as workdir:
        shots = capture_outputs(workdir)
        point = pick_point()
        if point is None:
            return 0
        name, logical, path = output_at(point, shots)
        shot = Image.open(path).convert("RGB")
        ratio = (shot.width / logical["width"], shot.height / logical["height"])
        click = to_pixels(*point, logical, ratio)

        run = os.path.join(RUNS, datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))
        os.makedirs(run, exist_ok=True)
        shutil.copy(path, os.path.join(run, "screen.png"))
        record = {"click": [round(c) for c in click], "output": name, "logical": logical, "ratio": ratio, "result": None}
        try:
            rect, report = locate(shot, click, run)
            record.update(report, result=rect and list(rect))
        except Failure as error:
            record["error"] = str(error)
            raise
        finally:
            with open(os.path.join(run, "run.json"), "w", encoding="utf-8") as handle:
                json.dump(record, handle, indent=2)
            prune()

        if rect is None:
            notify("Nothing found", f"no item under the click (noul {report['present']:.2f}); clipboard unchanged")
            return 0
        out = os.path.join(run, "copied.png")
        shot.crop(rect).save(out)
        with open(out, "rb") as handle:
            subprocess.run(["wl-copy", "--type", "image/png"], stdin=handle, check=True)
        notify("Copied", f"{rect[2] - rect[0]}x{rect[3] - rect[1]} {report['chosen']} to the clipboard")
    return 0


# Cases -----------------------------------------------------------------------------------

FLAG_CHOICES = {
    "right": "It was right: keep it as a case",
    "region": "Drag the region I wanted",
    "nothing": "Nothing should have been copied",
}


def flag():
    runs = sorted(os.listdir(RUNS)) if os.path.isdir(RUNS) else []
    if not runs:
        notify("Nothing to flag", "no smart-shot capture yet")
        return 0
    run = os.path.join(RUNS, runs[-1])
    with open(os.path.join(run, "run.json"), encoding="utf-8") as handle:
        record = json.load(handle)
    menu = "\n".join(FLAG_CHOICES.values())
    done = subprocess.run(
        ["fuzzel", "--dmenu", "--index", "--prompt", f"{runs[-1]}: "], input=menu, capture_output=True, text=True, check=False
    )
    index = done.stdout.strip()
    if done.returncode or not index.isdigit() or int(index) >= len(FLAG_CHOICES):
        return 0
    choice = list(FLAG_CHOICES)[int(index)]
    if choice == "right":
        expected = record.get("result")
    elif choice == "nothing":
        expected = None
    else:
        drag = subprocess.run(["slurp", "-f", "%x %y %w %h"], capture_output=True, text=True, check=False)
        if drag.returncode:
            return 0
        x, y, w, h = map(int, drag.stdout.split())
        l, t = to_pixels(x, y, record["logical"], record["ratio"])
        r, b = to_pixels(x + w, y + h, record["logical"], record["ratio"])
        expected = [round(l), round(t), round(r), round(b)]
    case = os.path.join(CASES, runs[-1])
    os.makedirs(case, exist_ok=True)
    shutil.copy(os.path.join(run, "screen.png"), os.path.join(case, "screen.png"))
    with open(os.path.join(case, "case.json"), "w", encoding="utf-8") as handle:
        json.dump({"click": record["click"], "expected": expected, "got": record.get("result")}, handle, indent=2)
    notify("Case saved", f"{case}\n`smart-shot test` replays every case")
    return 0


def iou(a, b):
    l, t, r, bottom = max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])
    inter = max(0, r - l) * max(0, bottom - t)
    return inter / (area(a) + area(b) - inter)


def run_case(case, out):
    with open(os.path.join(case, "case.json"), encoding="utf-8") as handle:
        spec = json.load(handle)
    shot = Image.open(os.path.join(case, "screen.png")).convert("RGB")
    os.makedirs(out, exist_ok=True)
    name = os.path.basename(case)
    try:
        rect, report = locate(shot, spec["click"], out)
    except Failure as error:
        return {"name": name, "ok": False, "note": f"error: {error}"}
    expected = spec["expected"]
    score = iou(rect, expected) if rect and expected else None
    ok = rect is None if expected is None else score is not None and score >= PASS_IOU
    view = shot.copy()
    draw = ImageDraw.Draw(view)
    if expected:
        draw.rectangle(expected, outline=(0, 200, 0), width=3)
    if rect:
        draw.rectangle(rect, outline=(255, 0, 0), width=3)
    cx, cy = spec["click"]
    draw.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=(255, 0, 255))
    view.save(os.path.join(out, "result.png"))
    with open(os.path.join(out, "report.json"), "w", encoding="utf-8") as handle:
        json.dump({**report, "result": rect and list(rect), "expected": expected}, handle, indent=2)
    note = f"{report['chosen']}, iou {score:.2f}" if score is not None else report["chosen"]
    return {"name": name, "ok": ok, "note": note}


def test(names, jobs):
    cases = [os.path.join(CASES, n) for n in (names or (sorted(os.listdir(CASES)) if os.path.isdir(CASES) else []))]
    if not cases:
        print(f"no cases in {CASES}: flag a capture with `smart-shot flag`", file=sys.stderr)
        return 2
    out = os.path.join(STATE, "test")
    shutil.rmtree(out, ignore_errors=True)
    with concurrent.futures.ThreadPoolExecutor(jobs) as pool:
        results = list(pool.map(lambda c: run_case(c, os.path.join(out, os.path.basename(c))), cases))
    for r in results:
        print(f"{'pass' if r['ok'] else 'FAIL'}  {r['name']}  {r['note']}")
    passed = sum(r["ok"] for r in results)
    print(f"{passed}/{len(results)} passed; each case's result.png (expected green, got red) is in {out}/")
    return 0 if passed == len(results) else 1


def main():
    parser = argparse.ArgumentParser(prog="smart-shot", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command")
    commands.add_parser("flag", help="label the last capture as a test case")
    tester = commands.add_parser("test", help="replay the cases against the live API")
    tester.add_argument("cases", nargs="*", help=f"case names in {CASES} (default: all)")
    tester.add_argument("-j", "--jobs", type=int, default=4, help="cases run in parallel (default 4)")
    args = parser.parse_args()
    try:
        if args.command == "flag":
            return flag()
        if args.command == "test":
            return test(args.cases, args.jobs)
        os.makedirs(RUNS, exist_ok=True)
        return capture()
    except (Failure, OSError, subprocess.CalledProcessError, KeyError, TypeError, ValueError) as error:
        if args.command != "test":
            notify("Smart screenshot failed", f"{error}; clipboard unchanged")
        print(f"smart-shot: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
