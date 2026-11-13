"""Whether a Claude session still has background work running after its turn ended.

Claude Code writes each launch (an async subagent, a background shell, a Monitor) into the
session's transcript, and a <task-notification> with a final status when it stops. Launches
from before the running process started died with the old process, so they don't count.
"""

import json
import os
import re
from datetime import datetime
from pathlib import Path

LAUNCHED = [
    re.compile(r"Async agent launched successfully\..*?agentId: (\w+)", re.S),
    re.compile(r"Command running in background with ID: (\w+)"),
    re.compile(r"Monitor started \(task (\w+)"),
]
MARKERS = ("Async agent launched", "running in background with ID", "Monitor started", "<task-notification>")
TASK_ID = re.compile(r"<task-id>(\w+)</task-id>")
FINAL = re.compile(r"<status>(completed|failed|killed|stopped)</status>")

_cache = {}


def config_dirs():
    if dirs := os.environ.get("ATTENTION_CLAUDE_DIRS"):
        return [Path(d) for d in dirs.split(":")]
    return [d for d in Path.home().glob(".claude*") if (d / "sessions").is_dir()]


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def live_session(session_id):
    """(config dir, start in ms) of the running Claude process for session_id, or None."""
    for directory in config_dirs():
        for path in (directory / "sessions").glob("*.json"):
            try:
                record = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                continue
            if record.get("sessionId") == session_id and alive(int(record.get("pid", 0))):
                return directory, int(record.get("startedAt", 0))
    return None


def texts(content):
    """The text blocks of a message's content, tool results included, without descending into quotes."""
    if isinstance(content, str):
        yield content
        return
    for block in content or []:
        if not isinstance(block, dict):
            continue
        if block.get("type") == "text":
            yield block.get("text", "")
        elif block.get("type") == "tool_result":
            yield from texts(block.get("content"))


def events(record):
    """('launch', id) and ('finish', id) for one transcript record. A marker counts only at the
    start of a tool result or of a queued notification, so a transcript that quotes one
    (a grep, a test file) launches nothing."""
    if record.get("type") == "queue-operation":
        bodies = [record.get("content") or ""]
    elif record.get("type") == "user":
        bodies = list(texts((record.get("message") or {}).get("content")))
    else:
        return
    for body in bodies:
        if not isinstance(body, str):
            continue
        if body.startswith("<task-notification>"):
            task, final = TASK_ID.search(body), FINAL.search(body)
            if task and final:
                yield "finish", task.group(1)
            continue
        for pattern in LAUNCHED:
            if match := pattern.match(body):
                yield "launch", match.group(1)


def timestamp_ms(record):
    try:
        return datetime.fromisoformat(record.get("timestamp", "").replace("Z", "+00:00")).timestamp() * 1000
    except (ValueError, AttributeError):
        return 0


def pending(lines, since_ms):
    """Task ids launched at or after since_ms with no final task-notification."""
    launched, finished = set(), set()
    for line in lines:
        if not any(marker in line for marker in MARKERS):
            continue
        try:
            record = json.loads(line)
        except ValueError:
            continue
        for kind, task in events(record):
            if kind == "finish":
                finished.add(task)
            elif timestamp_ms(record) >= since_ms:
                launched.add(task)
    return launched - finished


def running_tasks(session_id):
    found = live_session(session_id)
    if found is None:
        return set()
    directory, started = found
    transcript = next((directory / "projects").glob(f"*/{session_id}.jsonl"), None)
    if transcript is None:
        return set()
    try:
        info = transcript.stat()
    except OSError:
        return set()
    stamp = (info.st_size, info.st_mtime_ns, started)
    cached = _cache.get(transcript)
    if cached and cached[0] == stamp:
        return cached[1]
    with open(transcript, encoding="utf-8", errors="replace") as handle:
        result = pending(handle, started)
    _cache[transcript] = (stamp, result)
    return result
