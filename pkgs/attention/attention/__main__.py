"""attention: go to whatever needs you most (docs/adr/0011-attention-queue-model.md).

    attention next      go to the top item; on an unhandled agent you're watching, requeue it first
    attention list      the queue, highest first (--json for the bar widget)
    attention go ID     go to one item (a popup's click)
    attention ingest    read a DMS notification as JSON on stdin; store it if it is an item; pop up a new one, or one it raised
    attention watch     the watcher: keeps the agent marks current and counts watching time
    attention stale     marks stale herdr tabs, and closes those marked a day (GLOSSARY.md › Herdr)
    attention resume SOCKET SESSION CONFIG CWD
                        resumes a closed stale tab's Claude session in a new tab (its notification's action)
"""

import json
import os
import subprocess
import sys
import time

from . import agents as agent_items
from . import bands, herdr, messages, stale, store
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
    return {k: v for k, v in item.items() if k not in ("agent", "conversation")} | {"band_name": bands.NAMES[item["band"]]}


def cmd_list(as_json):
    with store.locked() as state:
        queue = current(state, time.time())
    if as_json:
        print(json.dumps([public(item) for item in queue]))
        return 0
    for item in queue:
        print(f"{bands.NAMES[item['band']]:<14} {messages.heading(item)}" + (f" · {item['detail'].splitlines()[0]}" if item["detail"] else ""))
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


def notify(title, body, button, *command, transient=True):
    """A notification whose click on `button` runs `attention COMMAND...`. Detached, since it waits for the click."""
    script = (
        'action=$(notify-send --app-name=Attention $1 --action=default="$2" "$3" "$4"); '
        '[ "$action" = default ] || exit 0; bin=$5; shift 5; exec "$bin" "$@"'
    )
    argv = ["sh", "-c", script, "notify", "--transient" if transient else "", button, title, body, sys.argv[0], *command]
    if not transient:
        # A unit of its own: a oneshot service (attention stale) has its leftover processes killed when it exits.
        argv = ["systemd-run", "--user", "--quiet", "--collect", "-E", "PATH", "--", *argv]
    subprocess.Popen(
        argv,
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def popup(item):
    """A popup for a third-party item that became one; clicking it goes there."""
    notify(f"{bands.NAMES[item['band']]} · {messages.heading(item)}", item["detail"], "Open", "go", item["id"])


def cmd_ingest():
    try:
        notification = json.load(sys.stdin)
    except ValueError:
        sys.exit("attention ingest: expected a notification as JSON on stdin")
    item, pops_up = messages.ingest(notification, time.time())
    print(bands.NAMES[item["band"]] if item else "not an item")
    if pops_up:
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


class TabOps:
    Error = herdr.HerdrError

    @staticmethod
    def rename(path, tab_id, label):
        herdr.request(path, "tab.rename", {"tab_id": tab_id, "label": label})

    @staticmethod
    def close(path, tab_id):
        herdr.request(path, "tab.close", {"tab_id": tab_id})

    @staticmethod
    def closed(mark):
        """Not transient: it stays in the notification center, since the tab it names is gone."""
        body = " · ".join(filter(None, [mark["title"] or mark["body"], mark["space"]]))
        notify("Closed stale tab", body, "Resume", "resume", mark["socket"], mark["session_id"], mark["config"], mark["cwd"], transient=False)


def judge(path, agent, others):
    """The config dir of the account holding a tab's Claude session if the tab is stale, else None."""
    found = stale.transcript(agent.session_id)
    if found is None:
        return None
    at = stale.last_input(agent, found[1])
    if at is None or time.time() - at < stale.IDLE_SECONDS or herdr.background_busy(agent):
        return None
    for pane in others:
        try:
            info = herdr.request(path, "pane.process_info", {"pane_id": pane["pane_id"]})
        except herdr.HerdrError:
            return None
        if not stale.quiet(info.get("process_info"), stale.nvim_clean):
            return None
    return found[0]


def cmd_stale():
    now = time.time()
    snaps, unreachable = herdr.snapshots()
    live = herdr.agents_in(snaps)
    with store.locked() as state:
        queue = build(state, live, now, unreachable=unreachable)
        open_ids = {item["id"] for item in queue if item["kind"] == "agent"}
        stale.sweep(state.stale, snaps, unreachable, live, open_ids, agent_items.mark_key, now, judge, TabOps)
    return 0


def cmd_resume(socket_path, session_id, config_dir, cwd):
    """claude-prompt-tab focuses the new tab in herdr; going to its agent raises the terminal too."""
    try:
        herdr.resume(socket_path, session_id, config_dir, cwd)
    except (herdr.HerdrError, OSError, subprocess.TimeoutExpired) as error:
        toast(f"Couldn't resume: {error}")
        return 1
    for _ in range(25):
        snaps, _ = herdr.snapshots()
        agent = next((a for a in herdr.agents_in(snaps) if a.session_id == session_id and a.socket == socket_path), None)
        if agent is not None:
            try:
                herdr.go(agent)
            except (herdr.HerdrError, subprocess.TimeoutExpired) as error:
                toast(f"Resumed, but couldn't raise it: {error}")
            return 0
        time.sleep(0.2)
    return 0


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
    if command == "stale":
        return cmd_stale()
    if command == "resume" and len(argv) == 6:
        return cmd_resume(*argv[2:])
    print(__doc__.strip(), file=sys.stderr if command not in ("-h", "--help") else sys.stdout)
    return 0 if command in ("-h", "--help") else 2


if __name__ == "__main__":
    sys.argv[0] = os.environ.get("ATTENTION_BIN", "attention")
    sys.exit(main(sys.argv))
