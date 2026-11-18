"""Focus an app's niri window when its notification's default action runs.

Stands in for an xdg-activation token: the notification server (DMS's
Quickshell) sends none, so an app's own focus request after a click carries an
invalid serial, which niri refuses. Watches the session bus with
`busctl monitor`: each Notify call's `sender-pid` hint (else the caller's pid)
is tied to the id the server's reply returns, and an `ActionInvoked` for that
id with the "default" action focuses the most recently focused window of that
pid or its nearest ancestor that has one.
"""

import argparse
import json
import subprocess
from collections import OrderedDict

IFACE = "org.freedesktop.Notifications"
KEEP = 1000


def log(*parts):
    print(*parts, flush=True)


def parent_pid(pid):
    try:
        with open(f"/proc/{pid}/stat") as f:
            # comm may hold spaces or parens; the ppid follows the last ')'.
            return int(f.read().rsplit(")", 1)[1].split()[1])
    except (OSError, IndexError, ValueError):
        return None


def focus_stamp(window):
    stamp = window.get("focus_timestamp") or {}
    return stamp.get("secs", 0), stamp.get("nanos", 0)


def pick_window(windows, pid, parent=parent_pid):
    """The window to focus for pid: its own, else its nearest ancestor's."""
    seen = set()
    while pid and pid > 1 and pid not in seen:
        seen.add(pid)
        own = [w for w in windows if w.get("pid") == pid]
        if own:
            return max(own, key=focus_stamp)
        pid = parent(pid)
    return None


class Tracker:
    """Maps notification ids to the pid that sent them, from bus messages."""

    def __init__(self, caller_pid):
        self.caller_pid = caller_pid
        self.pending = {}
        self.ids = OrderedDict()

    def handle(self, msg):
        """Returns the pid to focus when msg invokes a known notification."""
        kind = msg.get("type")
        data = (msg.get("payload") or {}).get("data") or []
        notify = msg.get("member") == "Notify" and len(data) >= 7
        if kind == "method_call" and notify:
            hint = data[6].get("sender-pid")
            pid = hint["data"] if hint else self.caller_pid(msg.get("sender"))
            self.pending[(msg.get("sender"), msg.get("cookie"))] = pid
        elif kind == "method_return":
            key = (msg.get("destination"), msg.get("reply_cookie"))
            if key in self.pending:
                pid = self.pending.pop(key)
                if pid and data:
                    self.ids[data[0]] = pid
                    self.ids.move_to_end(data[0])
                    while len(self.ids) > KEEP:
                        self.ids.popitem(last=False)
        elif kind == "signal" and msg.get("member") == "ActionInvoked":
            if len(data) == 2 and data[1] == "default":
                return self.ids.get(data[0])
        return None


def main():
    parser = argparse.ArgumentParser(description="Focus a notification's app")
    parser.add_argument("--niri", default="niri")
    parser.add_argument("--busctl", default="busctl")
    args = parser.parse_args()

    def caller_pid(name):
        out = subprocess.run(
            [args.busctl, "--user", "--json=short", "call",
             "org.freedesktop.DBus", "/org/freedesktop/DBus",
             "org.freedesktop.DBus", "GetConnectionUnixProcessID", "s", name],
            capture_output=True, text=True,
        )
        try:
            return json.loads(out.stdout)["data"][0]
        except (ValueError, KeyError, IndexError):
            return None

    tracker = Tracker(caller_pid)
    cmd = [
        args.busctl, "--user", "monitor", "--json=short",
        "--match", f"interface='{IFACE}'",
        "--match", f"type='method_return',sender='{IFACE}'",
    ]
    with subprocess.Popen(cmd, stdout=subprocess.PIPE, text=True) as p:
        assert p.stdout is not None
        for line in p.stdout:
            try:
                pid = tracker.handle(json.loads(line))
            except (ValueError, AttributeError, TypeError):
                continue
            if pid is None:
                continue
            out = subprocess.run(
                [args.niri, "msg", "--json", "windows"],
                capture_output=True, text=True,
            )
            try:
                window = pick_window(json.loads(out.stdout), pid)
            except ValueError:
                window = None
            if window is None:
                log(f"no window for pid {pid}")
                continue
            log(f"focusing {window.get('app_id')} (pid {pid})")
            subprocess.run(
                [args.niri, "msg", "action", "focus-window",
                 "--id", str(window["id"])]
            )
    raise SystemExit(f"busctl monitor exited with {p.returncode}")


if __name__ == "__main__":
    main()
