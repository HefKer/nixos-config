"""Source: third-party notifications (Discord, the phone), handed over by the DMS plugin and stored."""

import subprocess
import uuid

from . import bands, classify, store


def ingest(notification, now, place=classify.place):
    """Stores the notification as an item if it becomes one; returns the item, or None."""
    name = place(notification)
    if name is None:
        return None
    item = {
        "id": f"message/{uuid.uuid4().hex[:12]}",
        "kind": "message",
        "band": bands.MESSAGE_BANDS[name],
        "order": now,
        "source": classify.source(notification),
        "dms_id": notification.get("id"),
        "title": notification.get("summary", "").translate(classify.ISOLATES).strip(),
        "detail": notification.get("body", "").strip(),
    }
    with store.locked() as state:
        state.messages[item["id"]] = item
    return item


def items(state):
    return list(state.messages.values())


def invoke(dms_id):
    """Runs the original notification's default action through the DMS plugin; False if it has none or is gone."""
    try:
        done = subprocess.run(
            ["dms", "ipc", "call", "attention", "invoke", str(dms_id)],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    return done.stdout.strip() == "INVOKED"


def go(item):
    """Going to a third-party item handles it: its action runs, or its full text is shown."""
    with store.locked() as state:
        state.messages.pop(item["id"], None)
    if item.get("dms_id") is None or not invoke(item["dms_id"]):
        subprocess.run(
            ["notify-send", "--app-name=Attention", "--transient", item["title"] or "Notification", item["detail"]],
            check=False,
        )
