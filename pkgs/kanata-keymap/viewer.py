"""kanata-keymap: toggle the keymap viewer, a page served on localhost in a bare qutebrowser window."""

import json
import os
import signal
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "kanata-keymap"
DMS_COLORS = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "DankMaterialShell/dms-colors.json"
PIDFILE = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "kanata-keymap.pid"
PAGE = Path(os.environ["KEYMAP_PAGE"])
# niri's floating rule for the viewer matches this.
APP_ID = "kanata-keymap"


def mtime(path):
    try:
        return path.stat().st_mtime_ns
    except OSError:
        return 0


def _mix(a, b, t):
    pa = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    pb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(pa, pb))


def theme():
    """The page's CSS variables from DMS's matugen palette, in its current mode."""
    try:
        dms = json.loads(DMS_COLORS.read_text())
        c = dms["colors"][dms.get("mode", "dark")]
    except (OSError, ValueError, KeyError):
        c = {}
    g = lambda k, d: c.get(k, d)
    key, sub = g("surface_container_high", "#2b2930"), g("on_surface_variant", "#cac4d0")
    return {
        "bg": g("surface", "#1d1b20"),
        "key": key,
        "border": g("outline", "#938f99"),
        "legend": g("on_surface", "#e6e0e9"),
        "sub": sub,
        "dim": _mix(key, sub, 0.45),
        "held": g("primary_container", "#4f378b"),
        "on-held": g("on_primary_container", "#eaddff"),
        "hit": g("tertiary", "#efb8c8"),
        "on-hit": g("on_tertiary", "#492532"),
        "accent": g("primary", "#d0bcff"),
    }


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def send(self, body, ctype):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        path = self.path.split("?")[0]
        if path == "/":
            self.send(PAGE.read_bytes(), "text/html; charset=utf-8")
        elif path == "/keymap.json":
            self.send((CACHE / "keymap.json").read_bytes(), "application/json")
        elif path == "/keymap.svg":
            self.send((CACHE / "keymap.svg").read_bytes(), "image/svg+xml")
        elif path == "/state":
            state = {"keymap": mtime(CACHE / "keymap.json"), "theme_stamp": mtime(DMS_COLORS), "theme": theme()}
            self.send(json.dumps(state).encode(), "application/json")
        elif path == "/quit":
            self.send(b"", "text/plain")
            os.kill(os.getpid(), signal.SIGTERM)
        else:
            self.send_error(404)


def running():
    try:
        pid = int(PIDFILE.read_text())
        # A stale pidfile's pid may since belong to another process.
        if b"kanata-keymap" in Path(f"/proc/{pid}/cmdline").read_bytes():
            return pid
    except (OSError, ValueError):
        pass
    return None


def main():
    if pid := running():
        os.kill(pid, signal.SIGTERM)
        return
    if not (CACHE / "keymap.json").exists():
        # Before the first render, or after a failed one, there is nothing to show yet.
        subprocess.run(["systemctl", "--user", "start", "kanata-keymap-render.service"], check=False)
    PIDFILE.write_text(str(os.getpid()))
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    bg = theme()["bg"]
    # qutebrowser, since chromium's --app window ignores --class on Wayland. --temp-basedir keeps the
    # page out of the real profile's history; passthrough mode hands every key to the page.
    browser = subprocess.Popen(
        ["qutebrowser", "--temp-basedir", "--desktop-file-name", APP_ID,
         "-s", "statusbar.show", "never", "-s", "tabs.show", "never", "-s", "window.hide_decoration", "true",
         "-s", "colors.webpage.bg", bg,
         f"http://127.0.0.1:{server.server_port}/", ":mode-enter passthrough"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    signal.signal(signal.SIGTERM, lambda *_: browser.terminate())
    try:
        browser.wait()
    finally:
        if running() == os.getpid():
            PIDFILE.unlink(missing_ok=True)


if __name__ == "__main__":
    sys.exit(main())
