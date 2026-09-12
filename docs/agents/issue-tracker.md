# Issue tracker: GitHub, in a separate private repo

Code is public in `HefKer/nixos-config`. Issues are private in **`HefKer/nixos-issues`**, a
repo that holds no code — only its issue tracker. Use the `gh` CLI for all operations.

The config is public as a portfolio piece and to share modules with friends; the backlog is
private because it describes machines, a home network, and their attack surface. The split
keeps both without a second copy of the code to keep in sync.

## Every command names the repo

`gh` infers the repo from `git remote -v`, which resolves to `nixos-config` — the wrong one.
Pass `--repo HefKer/nixos-issues` on every invocation. Exporting `GH_REPO` does not help:
each shell command runs in a fresh shell, so the variable is gone by the next call.

## Conventions

- **Create**: `gh issue create --repo HefKer/nixos-issues --title "..." --body-file -` (heredoc into stdin for multi-line bodies)
- **Read**: `gh issue view <n> --repo HefKer/nixos-issues --comments`
- **List**: `gh issue list --repo HefKer/nixos-issues --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`, with `--label` / `--state` / `--milestone` filters
- **Comment**: `gh issue comment <n> --repo HefKer/nixos-issues --body "..."`
- **Label**: `gh issue edit <n> --repo HefKer/nixos-issues --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <n> --repo HefKer/nixos-issues --comment "..."`

One **milestone** per effort, named for the effort (`hm-dotfiles`, `config-cleanup`). It
replaces the `.scratch/<feature>/` directory as the grouping unit and gives the effort a
visible finish line.

## Linking issues to the code

A commit or PR in `nixos-config` that writes `HefKer/nixos-issues#12` leaves a backlink in
that issue's timeline. Closing keywords (`Fixes #12`) do not reach across repos, so close
the issue yourself with `gh issue close`, quoting the commit SHA.

The backlink renders as a dead reference to anyone without access to the private repo, so a
public commit message can carry the issue number without leaking its contents.

## Efforts that stay local

Keep an effort whose subject **is** the homelab in `.scratch/<effort>/` as markdown, per the
conventions below. Notes about infrastructure must stay readable while that infrastructure
is down, half-built, or being reinstalled — which is exactly when they are needed.
`.scratch/homelab/` is the standing case.

`.scratch/` is also still the live tracker for efforts created before the split, until each
is migrated. Check both places when looking for existing work on a topic.

Local conventions: one directory per effort, `PRD.md` for the spec, issues as
`issues/<NN>-<slug>.md` numbered from `01`, a `Status:` line near the top carrying a role
string from `triage-labels.md`, a `Blocked by: NN, NN` line for edges, and conversation
appended under a `## Comments` heading.

Note that `.scratch/` is untracked — a global ignore rule covers it — so it lives on one
machine with no backup. That asymmetry is the reason everything else moved to GitHub.

## When a skill says "publish to the issue tracker"

Create a GitHub issue in `HefKer/nixos-issues`.

## When a skill says "fetch the relevant ticket"

`gh issue view <n> --repo HefKer/nixos-issues --comments`.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature
requests; `/triage` reads this flag.)_ PRs land on the public code repo, which has no issue
tracker, so the surfaces are disjoint by construction.

## Wayfinding operations

Used by `/wayfinder`. The **map** is one issue; each ticket is a **child** issue.

- **Map**: an issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
- **Child ticket**: a GitHub sub-issue of the map —
  `gh api --method POST repos/HefKer/nixos-issues/issues/<map>/sub_issues -F sub_issue_id=<child-db-id>`.
  Label it `wayfinder:<type>` (`research` / `prototype` / `grilling` / `task`).
- **Database ids**: the dependency and sub-issue endpoints take an issue's numeric **database
  id**, not its `#number` and not its `node_id`. Fetch it with
  `gh api repos/HefKer/nixos-issues/issues/<n> --jq .id`.
- **Blocking**: native issue dependencies, visible in the UI —
  `gh api --method POST repos/HefKer/nixos-issues/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`.
  A ticket is unblocked when every blocker is closed.
- **Reading edges back**: `gh api repos/HefKer/nixos-issues/issues/<n>/dependencies/blocked_by`
  is authoritative and immediate. The `issue_dependencies_summary.blocked_by` count on the
  issue object lags a write by a few seconds, so read the dependencies endpoint when acting
  on an edge you just created.
- **Frontier query**: list the map's open sub-issues, drop any with an open blocker or an
  assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --repo HefKer/nixos-issues --add-assignee @me`, the session's
  first write.
- **Resolve**: comment the answer, close the issue, then append a context pointer (gist +
  link) to the map's Decisions-so-far.
