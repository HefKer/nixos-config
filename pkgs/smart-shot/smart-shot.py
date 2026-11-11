"""Click an object on screen and copy a screenshot cropped to it, with Jev's Box finding its edges.

The output under the cursor is captured before the click, so the picker's overlay never shows.
A copy marked at the click goes to `jev box` with a companion Noul; the crop is cut from the
unmarked capture. Each run's requests, answers and sent images are kept in
$XDG_STATE_HOME/smart-shot/ for reruns with `jev box`.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

# Tuning: everything prototyping is expected to change lives here.
BOX_QUESTION = "the table, image, or other distinct object the red marker is on in `image`"
NOUL_QUESTION = "Is the red marker on a distinct object such as a table or image in `image`?"
YES_THRESHOLD = 0.7  # the noul at or above this reads as yes
PAD_PX = 6  # added to each side of the final crop, in screen pixels: box edges aren't pixel-exact
SECOND_PASS_BELOW = 0.5  # re-ask on a full-resolution crop when the box spans less than this of both sides
SECOND_PASS_MARGIN = 0.25  # the second pass's crop: the box grown by this fraction of its size per side
MARKER = {"radius": 14, "width": 4, "colour": (255, 0, 0)}  # a ring around the click, plus a centre dot

# The API's image limits; it never resizes.
MAX_SIDE = 1568
MIN_SIDE = 280

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "smart-shot")


class Failure(Exception):
    pass


def notify(summary, body=""):
    subprocess.run(["notify-send", "-a", "smart-shot", summary, body], check=False)


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


def under(point, shots):
    """The capture holding `point`, and the point in its pixels (which differ under scaling)."""
    x, y = point
    for logical, path in shots.values():
        if logical["x"] <= x < logical["x"] + logical["width"] and logical["y"] <= y < logical["y"] + logical["height"]:
            shot = Image.open(path).convert("RGB")
            ratio_x, ratio_y = shot.width / logical["width"], shot.height / logical["height"]
            return shot, ((x - logical["x"]) * ratio_x, (y - logical["y"]) * ratio_y)
    raise Failure("the click is on no output")


def grow(region, size, bounds):
    """`region` widened about its centre to at least `size` per side, inside `bounds`."""
    left, top, right, bottom = region
    width, height = bounds
    for low, high, limit, axis in ((left, right, width, 0), (top, bottom, height, 1)):
        short = max(0, min(size, limit) - (high - low))
        low, high = low - short / 2, high + short / 2
        if low < 0:
            low, high = 0, high - low
        if high > limit:
            low, high = max(0, low - (high - limit)), limit
        if axis == 0:
            left, right = low, high
        else:
            top, bottom = low, high
    return tuple(round(edge) for edge in (left, top, right, bottom))


def ask_box(shot, region, click, tag, noul):
    """Box over `region` of `shot`, marked at `click`; the box in `shot` pixels and the noul, if asked."""
    left, top, right, bottom = region
    image = shot.crop(region)
    scale = min(1.0, MAX_SIDE / image.width, MAX_SIDE / image.height)
    if scale < 1:
        image = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    cx, cy = (click[0] - left) * scale, (click[1] - top) * scale
    draw = ImageDraw.Draw(image)
    r, colour = MARKER["radius"], MARKER["colour"]
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=colour, width=MARKER["width"])
    draw.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=colour)

    sent = os.path.join(STATE, f"{tag}.png")
    image.save(sent)
    command = ["jev", "box", sent, BOX_QUESTION, "--json", "--save-request", os.path.join(STATE, f"{tag}-request.json")]
    if noul:
        command += ["--noul", NOUL_QUESTION, "-t", str(YES_THRESHOLD)]
    try:
        done = subprocess.run(command, capture_output=True, text=True, check=False)
    except OSError as error:
        raise Failure(f"can't run jev: {error.strerror}") from None
    # jev exits 1 for a noul below the threshold, which is still an answer; 2 is a failure.
    if done.returncode not in (0, 1):
        raise Failure(done.stderr.strip() or f"jev exited {done.returncode}")
    with open(os.path.join(STATE, f"{tag}-answer.json"), "w", encoding="utf-8") as handle:
        handle.write(done.stdout)
    answers = json.loads(done.stdout)
    edges = answers["box"]["box"]
    width, height = right - left, bottom - top
    box = (
        left + edges["left"] * width,
        top + edges["top"] * height,
        left + edges["right"] * width,
        top + edges["bottom"] * height,
    )
    return box, answers["noul"]["noul"] if noul else None


def run():
    os.makedirs(STATE, exist_ok=True)
    for name in os.listdir(STATE):
        os.remove(os.path.join(STATE, name))
    with tempfile.TemporaryDirectory(prefix="smart-shot-") as workdir:
        shots = capture_outputs(workdir)
        point = pick_point()
        if point is None:
            return 0
        shot, click = under(point, shots)
        whole = (0, 0, shot.width, shot.height)

        box, yes = ask_box(shot, whole, click, "pass1", noul=True)
        if yes < YES_THRESHOLD:
            notify("Nothing found", f"no distinct object under the click (noul {yes:.2f}); clipboard unchanged")
            return 0

        downscaled = max(shot.width, shot.height) > MAX_SIDE
        box_w, box_h = box[2] - box[0], box[3] - box[1]
        if downscaled and box_w < SECOND_PASS_BELOW * shot.width and box_h < SECOND_PASS_BELOW * shot.height:
            mx, my = box_w * SECOND_PASS_MARGIN, box_h * SECOND_PASS_MARGIN
            region = (
                min(box[0] - mx, click[0]),
                min(box[1] - my, click[1]),
                max(box[2] + mx, click[0]),
                max(box[3] + my, click[1]),
            )
            box, _ = ask_box(shot, grow(region, MIN_SIDE, shot.size), click, "pass2", noul=False)

        crop = (
            max(0, round(box[0]) - PAD_PX),
            max(0, round(box[1]) - PAD_PX),
            min(shot.width, round(box[2]) + PAD_PX),
            min(shot.height, round(box[3]) + PAD_PX),
        )
        if crop[2] - crop[0] < 1 or crop[3] - crop[1] < 1:
            raise Failure(f"empty box {box}")
        out = os.path.join(workdir, "crop.png")
        shot.crop(crop).save(out)
        with open(out, "rb") as handle:
            subprocess.run(["wl-copy", "--type", "image/png"], stdin=handle, check=True)
        shutil.copy(out, os.path.join(STATE, "copied.png"))
        notify("Copied", f"{crop[2] - crop[0]}x{crop[3] - crop[1]} object to the clipboard")
    return 0


def main():
    try:
        return run()
    except (Failure, subprocess.CalledProcessError, KeyError, TypeError, ValueError) as error:
        notify("Smart screenshot failed", f"{error}; clipboard unchanged")
        print(f"smart-shot: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
