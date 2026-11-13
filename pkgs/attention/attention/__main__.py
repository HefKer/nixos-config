"""attention: go to whatever needs you most (docs/adr/0011-attention-queue-model.md).

    attention next      go to the top item; on an unhandled agent you're watching, requeue it first
    attention list      the queue, highest first (--json for the bar widget)
    attention go ID     go to one item (a popup's click)
    attention ingest    read a DMS notification as JSON on stdin; store and pop up an item if it is one
    attention watch     the watcher: keeps the agent marks current and counts watching time
"""

import json
import os
import subprocess
import sys
import time

from . import agents as agent_items
from . import bands, herdr, messages, store
from .ranking import build, ranked, requeue

TICK = 1


def toast(text):
    subprocess.run(["dms", "ipc", "call", "toast", "info", text], capture_output=True, check=False)


def current(state, now):
    """The ranked queue, read live from herdr."""
    live, unreachable = herdr.agents()
    return build(state, live, now, unreachable=unreachable)


def go(item):
    if item["kind"] == "agent":
        herdr.go(item["agent"])
    else:
        messages.go(item)


def cmd_next():
    now = time.time()
    with store.locked() as state:
        queue = current(state, now)
        here = {item["id"] for item in queue if item["kind"] == "agent" and herdr.watching(item["agent"])}
        for item in queue:
            if item["id"] in here:
                requeue(state, item, now)
        queue = ranked(queue)
    target = next((item for item in queue if item["id"] not in here), None)
    if target is None:
        toast("Nothing else needs you" if here else "All clear")
        return 0
    go(target)
    subprocess.run(["repeat", "record", "attention", "next"], check=False)
    return 0


def public(item):
    return {k: v for k, v in item.items() if k != "agent"} | {"band_name": bands.NAMES[item["band"]]}


def cmd_list(as_json):
    with store.locked() as state:
        queue = current(state, time.time())
    if as_json:
        print(json.dumps([public(item) for item in queue]))
        return 0
    for item in queue:
        print(f"{bands.NAMES[item['band']]:<14} {item['title']}" + (f" · {item['detail'].splitlines()[0]}" if item["detail"] else ""))
    return 0


def cmd_go(item_id):
    with store.locked() as state:
        queue = current(state, time.time())
    item = next((item for item in queue if item["id"] == item_id), None)
    if item is None:
        toast("Already handled")
        return 0
    go(item)
    return 0


def popup(item):
    """A popup for a third-party item that became one; clicking it goes there. Detached, since it waits for the click."""
    title = f"{bands.NAMES[item['band']]} · {item['title']}"
    script = (
        'action=$(notify-send --app-name=Attention --transient --action=default=Open "$1" "$2"); '
        '[ "$action" = default ] && exec "$3" go "$4"'
    )
    subprocess.Popen(
        ["sh", "-c", script, "popup", title, item["detail"], sys.argv[0], item["id"]],
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def cmd_ingest():
    try:
        notification = json.load(sys.stdin)
    except ValueError:
        sys.exit("attention ingest: expected a notification as JSON on stdin")
    item = messages.ingest(notification, time.time())
    print(bands.NAMES[item["band"]] if item else "not an item")
    if item:
        popup(item)
    return 0


def watch_tick():
    now = time.time()
    with store.locked() as state:
        for item in current(state, now):
            if item["kind"] == "agent" and item["band"] == bands.DONE_AGENT:
                agent_items.watched(state.agents, item, herdr.watching(item["agent"]), now)


def cmd_watch():
    while True:
        try:
            watch_tick()
        except Exception as error:  # noqa: BLE001
            # One bad tick (a hung agent-notify, a transcript mid-write) mustn't drop the watch counts with the process.
            print(f"attention watch: {error!r}", file=sys.stderr, flush=True)
        time.sleep(TICK)


def main(argv):
    command = argv[1] if len(argv) > 1 else ""
    if command == "next":
        return cmd_next()
    if command == "list":
        return cmd_list("--json" in argv[2:])
    if command == "go" and len(argv) == 3:
        return cmd_go(argv[2])
    if command == "ingest":
        return cmd_ingest()
    if command == "watch":
        return cmd_watch()
    print(__doc__.strip(), file=sys.stderr if command not in ("-h", "--help") else sys.stdout)
    return 0 if command in ("-h", "--help") else 2


if __name__ == "__main__":
    sys.argv[0] = os.environ.get("ATTENTION_BIN", "attention")
    sys.exit(main(sys.argv))
