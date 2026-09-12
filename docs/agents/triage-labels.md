# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the
label strings used in this repo's tracker. They are identical — the labels exist in
`HefKer/nixos-issues` under their canonical names.

| Role in mattpocock/skills | Label in our tracker | Meaning                                  |
| ------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`            | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`              | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`         | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`         | `ready-for-human`    | Requires human implementation            |
| `wontfix`                 | `wontfix`            | Will not be actioned                     |

When a skill mentions a role ("apply the AFK-ready triage label"), use the label string from
the right-hand column.

In the local markdown efforts that `issue-tracker.md` keeps under `.scratch/`, the same
strings are the value of the `Status:` line.
