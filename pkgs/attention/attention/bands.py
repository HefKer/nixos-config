"""The fixed bands of the attention queue (docs/adr/0011-attention-queue-model.md), highest first."""

URGENT, BLOCKED_AGENT, REPLY_SOON, DONE_AGENT, LATER = range(5)

NAMES = {
    URGENT: "Urgent",
    BLOCKED_AGENT: "Blocked agent",
    REPLY_SOON: "Reply soon",
    DONE_AGENT: "Done agent",
    LATER: "Later",
}

# The bands the classifier may place a third-party item in; agents always sit in their own two.
MESSAGE_BANDS = {"urgent": URGENT, "reply_soon": REPLY_SOON, "later": LATER}
