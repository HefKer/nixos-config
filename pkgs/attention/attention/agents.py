"""Agent items: derived from herdr's agents at read time, with marks keyed to herdr's own sequence numbers.

A mark is only kept while the live agent still carries the sequence number it was made for, so a
restarted herdr, a closed pane or a new prompt leaves nothing behind. The marks hold what a
snapshot can't: when the agent entered its band, where it was requeued to, and how long it has
been watched.
"""

from . import bands

WATCH_SECONDS = 5
# A gap longer than this between two looks at a watched agent restarts its count.
MAX_WATCH_STEP = 2


def mark_key(agent):
    """The mark an agent's current state would carry, or None if it isn't in an agent band."""
    if agent.status == "blocked":
        return f"{agent.key}/blocked/{agent.state_seq}"
    if agent.status in ("done", "idle") and agent.completion_seq is not None:
        return f"{agent.key}/done/{agent.completion_seq}"
    return None


def observe(marks, agents, now, unreachable=()):
    """Brings the marks in line with the live agents: new ones for fresh blocked or done states,
    none for states that have gone. Only herdr's `done` (finished, not yet seen there) opens a
    done mark, so an agent idle since before the watcher ran never becomes an item. A session
    that didn't answer keeps its marks, since a slow reply isn't a restart."""
    live = {key: mark for key, mark in marks.items() if key.split("/", 1)[0] in unreachable}
    for agent in agents:
        key = mark_key(agent)
        if key is None:
            continue
        if key in marks or agent.status in ("blocked", "done"):
            live[key] = marks.get(key) or {"since": now, "order": now, "watched": 0, "handled": False}
    marks.clear()
    marks.update(live)


def items(marks, agents, busy):
    """The open agent items. `busy(agent)` says whether its turn ended with background work running."""
    found = []
    for agent in agents:
        mark = marks.get(mark_key(agent) or "")
        if not mark or mark["handled"]:
            continue
        band = bands.BLOCKED_AGENT if agent.status == "blocked" else bands.DONE_AGENT
        if band == bands.DONE_AGENT and busy(agent):
            continue
        found.append(
            {
                "id": mark_key(agent),
                "kind": "agent",
                "band": band,
                "order": mark["order"],
                "title": f"{agent.kind} {'needs you' if band == bands.BLOCKED_AGENT else 'finished'}",
                "detail": " · ".join(filter(None, [agent.title, agent.place])),
                "agent": agent,
            }
        )
    return found


def watched(marks, item, seeing, now):
    """Counts a look at a done agent's item; handled once seen for WATCH_SECONDS without a break."""
    mark = marks[item["id"]]
    if not seeing or item["band"] != bands.DONE_AGENT:
        mark["watched"] = 0
        mark.pop("seen_at", None)
        return
    last = mark.get("seen_at")
    if last is not None and now - last <= MAX_WATCH_STEP:
        mark["watched"] += now - last
    mark["seen_at"] = now
    if mark["watched"] >= WATCH_SECONDS:
        mark["handled"] = True
