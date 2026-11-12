# Attention queue model

Status: accepted

One bind, `Mod+Shift+N`, goes to whatever needs the user most. What it reads
is the attention queue, not the notification history: a notification informs,
an attention item waits on an action, and most notifications produce none.

- **Fixed bands, not a score.** Items rank Urgent > blocked agent > Reply soon
  > done agent > Later, oldest first within a band. A skipped item goes behind
  its peers. Agents always sit in their own two bands; a third-party item
  (Discord, the phone through KDE Connect) is placed into a band by rules
  first, then a Jev classifier given the sender's relationship (a contacts
  file in `~/polaris/`, kept out of this public repo) and source hints such as
  the Discord server. If the classifier is unreachable, the item goes to
  Later.
- **Agent items are derived, never stored.** They are computed from herdr's
  snapshot at read time, merged with the stored third-party items. A done
  agent is handled once watched for 5 s or prompted, a blocked one once
  unblocked; a third-party item once gone to. An agent whose turn ended while
  background work still runs is still working.
- **It is a flake package**, coupled to herdr, niri and DMS, with sources,
  queue and jump kept apart so it can graduate into the cross-platform app
  planned later ([ADR-0010](0010-where-new-software-goes.md)).

## Considered options

- **A numeric urgency score from the classifier.** Rejected: agents' position
  would drift with every message the model scores, and the order would stop
  being predictable. Rank depends on who is asking and why, which a band
  captures without that drift.
- **Classifying agents too.** Rejected: their status already says whether
  they are stalled or idle, better than a model could.
- **Storing agent items.** Rejected: a stored copy goes stale the moment herdr
  restarts or a pane closes.
- **Jumping counts as handled for agents.** Rejected: opening an agent and
  leaving without reading or answering it would drop it from the queue.
