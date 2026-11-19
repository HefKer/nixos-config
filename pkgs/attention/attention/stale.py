"""Stale tabs (GLOSSARY.md › Herdr): marked in the tab bar for a day, then closed with a
notification whose action resumes their Claude session in a new tab.

A tab is stale when its one agent is a Claude that is done and handled by the attention queue's
own rule (agents.py), its last input is IDLE_SECONDS old, and its other panes hold nothing
alive. Whatever can't be read keeps the tab.
"""

import json
import os
import re
import subprocess
from pathlib import Path

from . import claude

IDLE_SECONDS = 3 * 86400
MARK_SECONDS = 86400
MARK = "⌫"
SHELLS = {"fish", "bash", "zsh", "sh", "dash", "nu"}
# herdr-auto-title's position prefix (HERDR_AUTO_TITLE_POSITION).
POSITION = re.compile(r"^\d+ · ")


def key(session, tab_id, agent):
    """A mark's key. The agent's terminal is in it because herdr reuses tab ids."""
    return f"{session}/{tab_id}/{agent.terminal_id}"


def positions(snap, closing=()):
    """{tab id: its position in its space}, counting tabs in snapshot order (herdr's display order)."""
    seen, found = {}, {}
    for tab in snap.get("tabs", []):
        if tab["tab_id"] in closing:
            continue
        workspace = tab.get("workspace_id")
        seen[workspace] = seen.get(workspace, 0) + 1
        found[tab["tab_id"]] = seen[workspace]
    return found


def unmarked(label):
    """(whether the label is numbered, the label without its position)."""
    match = POSITION.match(label or "")
    return (True, label[match.end() :]) if match else (False, label or "")


def marked_label(position, numbered, body):
    marked = f"{MARK} {body}".rstrip()
    return f"{position} · {marked}" if numbered else marked


def named_by_hand(tab):
    """Whether herdr-auto-title holds the tab's label as one the user gave it (its manual-names.json)."""
    base = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    try:
        locked = json.loads((base / "herdr-auto-title/manual-names.json").read_text(encoding="utf-8")).get("locked_tabs") or {}
    except (OSError, ValueError, AttributeError):
        return False
    return bool(tab.get("label")) and locked.get(tab["tab_id"]) == tab.get("label")


def candidates(snap, agents, open_ids, mark_key):
    """(tab, its agent, its other panes) for each tab whose state alone allows it to be stale: one
    agent, a Claude with a session id, done or idle, and no open attention item."""
    for tab in snap.get("tabs", []):
        inside = [a for a in agents if a.tab_id == tab["tab_id"]]
        if len(inside) != 1:
            continue
        agent = inside[0]
        if agent.kind != "claude" or not agent.session_id or agent.status not in ("done", "idle"):
            continue
        if (mark_key(agent) or "") in open_ids:
            continue
        others = [p for p in snap.get("panes", []) if p["tab_id"] == tab["tab_id"] and p["pane_id"] != agent.pane_id]
        yield tab, agent, others


def transcript(session_id):
    """(config dir, transcript path) of a Claude session under whichever account holds it, or None."""
    for directory in claude.config_dirs():
        path = next((directory / "projects").glob(f"*/{session_id}.jsonl"), None)
        if path is not None:
            return directory, path
    return None


def drafts_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return Path(base) / "nvim/claude-drafts"


def last_input(agent, transcript_path):
    """When the user last gave the tab input: the later of its transcript's and its prompt draft's
    last write. None if the prompt pane holds a draft keyed to the pane, which closing would lose."""
    if (drafts_dir() / f"pane-{agent.pane_id.replace(':', '-')}.md").exists():
        return None
    times = []
    for path in (transcript_path, drafts_dir() / f"{agent.session_id}.md"):
        try:
            times.append(path.stat().st_mtime)
        except OSError:
            pass
    return max(times) if times else None


def quiet(info, nvim_clean):
    """Whether a pane holds nothing alive: an idle shell, or an nvim with no unsaved buffers."""
    processes = (info or {}).get("foreground_processes") or []
    if not processes:
        return False
    names = {p.get("name") for p in processes}
    if names <= SHELLS:
        return True
    return names == {"nvim"} and all(nvim_clean(p["pid"]) for p in processes)


def children(pid):
    found = []
    for path in Path(f"/proc/{pid}/task").glob("*/children"):
        try:
            found += [int(c) for c in path.read_text().split()]
        except (OSError, ValueError):
            pass
    return found


def nvim_clean(pid):
    """No file buffer with unsaved changes in the nvim at pid. Its server is the --embed child
    when it runs a UI, so that child's socket is asked too; an nvim that can't be asked isn't clean."""
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}")
    expr = 'len(filter(getbufinfo(), {_, b -> b.changed && getbufvar(b.bufnr, "&buftype") == ""}))'
    for candidate in [pid, *children(pid)]:
        sock = runtime / f"nvim.{candidate}.0"
        if not sock.is_socket():
            continue
        try:
            out = subprocess.run(
                ["nvim", "--server", str(sock), "--remote-expr", expr], capture_output=True, text=True, timeout=5, check=False
            )
        except (OSError, subprocess.TimeoutExpired):
            return False
        return out.returncode == 0 and out.stdout.strip() == "0"
    return False


def step(mark, stale, focused, now):
    """What a sweep does to one tab: mark it, keep its mark current, close it, or take the mark off.
    A focused tab is never closed, since the user is in it."""
    if not stale:
        return "unmark" if mark else None
    if mark is None:
        return "mark"
    if now - mark["since"] >= MARK_SECONDS and not focused:
        return "close"
    return "relabel"


def sweep(marks, snaps, unreachable, agents, open_ids, mark_key, now, judge, ops):
    """One pass over every session that answered. `judge(path, agent, others)` is the config dir of
    a tab found stale, else None; `ops` renames and closes tabs and sends the closing notification.
    A session that didn't answer keeps its marks; a failed herdr call leaves the mark as it was."""
    for k in [k for k, mark in marks.items() if mark["session"] not in snaps and mark["session"] not in unreachable]:
        del marks[k]
    for session, (path, snap) in snaps.items():
        own = {k: mark for k, mark in marks.items() if mark["session"] == session}
        inside = [a for a in agents if a.session == session]
        tabs = {tab["tab_id"]: tab for tab in snap.get("tabs", [])}
        plans = {}
        for tab, agent, others in candidates(snap, inside, open_ids, mark_key):
            k = key(session, tab["tab_id"], agent)
            config = judge(path, agent, others)
            plans[k] = (step(own.get(k), config is not None, tab.get("focused", False), now), tab, agent, config)
        for k, mark in own.items():
            if k not in plans:
                plans[k] = ("unmark", tabs.get(mark["tab_id"]), None, None)
        closing = {tab["tab_id"] for action, tab, _, _ in plans.values() if action == "close"}
        place = positions(snap, closing)
        for k, (action, tab, agent, config) in plans.items():
            try:
                apply(marks, k, action, tab, agent, config, session, path, snap, place, now, ops)
            except ops.Error as error:
                print(f"attention stale: {k}: {error}", flush=True)


def apply(marks, k, action, tab, agent, config, session, path, snap, place, now, ops):
    if action == "unmark":
        # An empty label hands the tab back to herdr-auto-title; a name the user gave it is put back instead.
        if tab is not None:
            ops.rename(path, tab["tab_id"], marks[k].get("manual") or "")
        del marks[k]
    elif action == "mark":
        numbered, body = unmarked(tab.get("label"))
        label = marked_label(place[tab["tab_id"]], numbered, body)
        ops.rename(path, tab["tab_id"], label)
        spaces = {w["workspace_id"]: w.get("label") for w in snap.get("workspaces", [])}
        marks[k] = {
            "session": session,
            "socket": str(path),
            "tab_id": tab["tab_id"],
            "since": now,
            "numbered": numbered,
            "body": body,
            "label": label,
            "manual": tab.get("label") if named_by_hand(tab) else None,
            "title": agent.title,
            "space": spaces.get(tab.get("workspace_id")) or "",
            "session_id": agent.session_id,
            "config": str(config),
            "cwd": agent.cwd,
        }
    elif action == "relabel":
        mark = marks[k]
        label = marked_label(place[tab["tab_id"]], mark["numbered"], mark["body"])
        if label != tab.get("label"):
            ops.rename(path, tab["tab_id"], label)
            mark["label"] = label
    elif action == "close":
        ops.close(path, tab["tab_id"])
        ops.closed(marks.pop(k))
