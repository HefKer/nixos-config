"""Source: herdr agents, read live from every running session's snapshot."""

import json
import os
import socket
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from . import claude

AGENT_NOTIFY = Path(
    os.environ.get("ATTENTION_AGENT_NOTIFY") or Path.home() / "dots/herdr/plugins/agent-notify/agent-notify.py"
)


class HerdrError(Exception):
    pass


def herdr_dir():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "herdr"


def sockets():
    """{session name: socket path} for every herdr session with a socket."""
    found = {}
    default = herdr_dir() / "herdr.sock"
    if default.is_socket():
        found["default"] = default
    for path in sorted((herdr_dir() / "sessions").glob("*/herdr.sock")):
        if path.is_socket():
            found[path.parent.name] = path
    return found


def request(path, method, params):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(2)
            client.connect(str(path))
            client.sendall((json.dumps({"id": "attention", "method": method, "params": params}) + "\n").encode())
            reply = b""
            while not reply.endswith(b"\n"):
                chunk = client.recv(1 << 20)
                if not chunk:
                    break
                reply += chunk
    except OSError as error:
        raise HerdrError(f"{path}: {error}") from None
    try:
        response = json.loads(reply)
    except ValueError:
        raise HerdrError(f"{path}: unreadable reply") from None
    if "error" in response:
        raise HerdrError(f"{method}: {response['error']}")
    return response["result"]


@dataclass
class Agent:
    session: str
    socket: str
    pane_id: str
    terminal_id: str
    kind: str
    status: str
    state_seq: int
    completion_seq: int | None
    session_id: str | None
    title: str
    place: str
    in_view: bool

    @property
    def key(self):
        return f"{self.session}/{self.terminal_id}"


def in_view(pane_id, snap):
    """Whether herdr's focus is on the agent, or on its tab's prompt pane (agent-notify's rule)."""
    focused = snap.get("focused_pane_id")
    if focused == pane_id:
        return True
    panes = {p["pane_id"]: p for p in snap.get("panes", [])}
    pane, agent = panes.get(focused), panes.get(pane_id)
    return bool(pane and agent and pane.get("label") == "prompt" and pane["tab_id"] == agent["tab_id"])


def agents_of(session, path, snap):
    workspaces = {w["workspace_id"]: w.get("label") for w in snap.get("workspaces", [])}
    tabs = {t["tab_id"]: t.get("label") for t in snap.get("tabs", [])}
    for a in snap.get("agents", []):
        place = " · ".join(filter(None, [session if session != "default" else "", workspaces.get(a.get("workspace_id")), tabs.get(a.get("tab_id"))]))
        yield Agent(
            session=session,
            socket=str(path),
            pane_id=a["pane_id"],
            terminal_id=a.get("terminal_id") or a["pane_id"],
            kind=a.get("agent") or "agent",
            status=a.get("agent_status") or "",
            state_seq=a.get("state_change_seq", 0),
            completion_seq=a.get("completion_seq"),
            session_id=(a.get("agent_session") or {}).get("value"),
            title=a.get("terminal_title_stripped") or "",
            place=place,
            in_view=in_view(a["pane_id"], snap),
        )


def agents():
    """Every agent in every reachable session; a session whose server is down has none."""
    found = []
    for session, path in sockets().items():
        try:
            result = request(path, "session.snapshot", {})
        except HerdrError:
            continue
        found.extend(agents_of(session, path, result.get("snapshot", result)))
    return found


def background_busy(agent):
    """A Claude whose turn ended while subagents, background shells or monitors still run."""
    return agent.kind == "claude" and bool(agent.session_id) and claude.running_tasks(agent.session_id)


def agent_notify(agent, command):
    """Runs agent-notify's `command` against the agent's pane, in the agent's herdr session."""
    env = dict(os.environ, HERDR_SOCKET_PATH=agent.socket)
    return subprocess.run(
        [sys.executable, str(AGENT_NOTIFY), command, agent.pane_id],
        env=env,
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )


def watching(agent):
    """In view in herdr, and shown in the focused terminal window."""
    return agent.in_view and agent_notify(agent, "watching").returncode == 0


def go(agent):
    """agent-notify's open_agent, then the terminal running it raised."""
    done = agent_notify(agent, "go")
    if done.returncode:
        raise HerdrError(done.stderr.strip() or f"agent-notify go exited {done.returncode}")
