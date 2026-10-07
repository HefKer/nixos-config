---
name: implement-ticket
description: "Implement one HefKer/nixos-issues ticket on a new branch, verified and reviewed, ready to merge."
disable-model-invocation: true
---

Implement ticket `$ARGUMENTS` from `HefKer/nixos-issues`. Instructions the user gives alongside
the number (merge, close the issue, skip review) override the matching step below.

1. **Read the ticket** with the **Read** command in `docs/agents/issue-tracker.md`, then the
   ADRs and `CONTEXT.md` terms it names as its authority. Done when you can write its
   acceptance criteria as a checklist, and know whether the ticket is **neutral** (moves,
   renames, splits: nothing built should change) or names the build differences it wants.
2. **Branch in a new worktree** off `main`:
   `git worktree add -b <type>/<slug> /home/hefker/nixos/<slug> main`, and work only there.
3. **Commit in chunks**, one reviewable step each, the message ending
   `(HefKer/nixos-issues#<n>)`. A chunk is done when `nix flake check` passes and
   `scripts/same-system main` shows either `identical`/a reorder with matching lists (neutral
   tickets) or only the differences the ticket names. Run `git add` on new files first, since
   the flake can't see untracked files.
4. **Check acceptance**: every criterion from step 1 ticked off by a command whose output you
   keep for the hand-back.
5. **Review** with `/code-review` from `main`. Fix every blocking finding in a new commit and
   re-run the step-3 checks on it.
6. **Hand back**: the branch and its commits, each acceptance criterion with its evidence, the
   `same-system` result per host, the review outcome, and what the user still has to run on
   the machine (`nixos-rebuild`, reboots). Leave merging and closing the issue to the user
   unless they asked for it.
