"""The attention queue: agent items and stored items merged, ranked by band, then oldest first."""

from . import agents as agent_items
from . import herdr, messages


def ranked(items):
    return sorted(items, key=lambda item: (item["band"], item["order"]))


def build(state, live_agents, now, busy=herdr.background_busy):
    """Every open item, ranked; the agent marks in `state` are brought up to date on the way."""
    agent_items.observe(state.agents, live_agents, now)
    return ranked(agent_items.items(state.agents, live_agents, busy) + messages.items(state))


def requeue(state, item, now):
    """Puts an item behind its band peers."""
    record = state.agents.get(item["id"]) if item["kind"] == "agent" else state.messages.get(item["id"])
    if record is not None:
        record["order"] = now
