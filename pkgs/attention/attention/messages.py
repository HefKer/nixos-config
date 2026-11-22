"""Source: third-party notifications (Discord, the phone), handed over by the DMS plugin and stored."""

import subprocess
import uuid

from . import bands, classify, store


def ingest(notification, now, place=classify.place):
    """Stores the notification if it becomes an item, joining its conversation's open item if there is one.
    Returns (item, whether it should pop up), or (None, False). A joined item keeps its id and place in line."""
    name = place(notification)
    if name is None:
        return None, False
    band = bands.MESSAGE_BANDS[name]
    key = classify.conversation(notification)
    latest = {
        "dms_id": notification.get("id"),
        "title": notification.get("summary", "").translate(classify.ISOLATES).strip(),
        "detail": notification.get("body", "").strip(),
    }
    with store.locked() as state:
        item = next((open_item for open_item in state.messages.values() if open_item.get("conversation") == key), None)
        if item is None:
            item = {
                "id": f"message/{uuid.uuid4().hex[:12]}",
                "kind": "message",
                "band": band,
                "order": now,
                "source": classify.source(notification),
                "conversation": key,
                "count": 0,
            }
            state.messages[item["id"]] = item
            raised = True
        else:
            raised = band < item["band"]
            item["band"] = min(band, item["band"])
        item.update(latest, count=item["count"] + 1)
    return item, raised


def heading(item):
    """The item's title, with its message count once a conversation holds more than one."""
    count = item.get("count", 1)
    return f"{item['title']} · {count} messages" if count > 1 else item["title"]


def items(state):
    return list(state.messages.values())


def invoke(dms_id, summary):
    """Runs the original notification's default action through the DMS plugin; False if it has none or is gone.
    The summary must match too, since DMS numbers notifications afresh after a shell restart."""
    try:
        done = subprocess.run(
            ["dms", "ipc", "call", "attention", "invoke", str(dms_id), summary],
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
    if item.get("dms_id") is None or not invoke(item["dms_id"], item["title"]):
        subprocess.run(
            ["notify-send", "--app-name=Attention", "--transient", item["title"] or "Notification", item["detail"]],
            check=False,
        )
