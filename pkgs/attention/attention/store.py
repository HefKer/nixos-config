"""The state files the watcher, the bind and the notification intake share, under one lock."""

import contextlib
import fcntl
import json
import os
from pathlib import Path


def state_dir():
    base = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    return Path(os.environ.get("ATTENTION_STATE_DIR") or Path(base) / "attention")


@contextlib.contextmanager
def locked():
    """Holds the state lock and yields a dict-like view of the state files, written back on exit."""
    directory = state_dir()
    directory.mkdir(parents=True, exist_ok=True)
    with open(directory / ".lock", "w", encoding="utf-8") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = State(directory)
        yield state
        state.save()


class State:
    """`agents`: marks on herdr's agent states, keyed to them. `messages`: stored third-party items."""

    FILES = ("agents", "messages")

    def __init__(self, directory):
        self.directory = directory
        for name in self.FILES:
            try:
                setattr(self, name, json.loads((directory / f"{name}.json").read_text(encoding="utf-8")))
            except (OSError, ValueError):
                setattr(self, name, {})

    def save(self):
        for name in self.FILES:
            path = self.directory / f"{name}.json"
            tmp = path.with_suffix(".tmp")
            tmp.write_text(json.dumps(getattr(self, name), indent=1), encoding="utf-8")
            tmp.replace(path)
