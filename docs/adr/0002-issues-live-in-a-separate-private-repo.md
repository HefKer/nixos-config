# Issues live in a separate private repo

Status: accepted

The config stays public at `HefKer/nixos-config`. The backlog moves to
`HefKer/nixos-issues`, a private repo holding no code — only its issue tracker.
The config is public because it is a listed portfolio project and because
sharing individual modules with friends is routine. The backlog is private
because issues describe machines, a home network, a hardware inventory and a
backup topology, and publishing is one-way: flipping a repo private later does
not retract what was already indexed.

Nothing in the public config is a credential. SSH is keys-only with
`openFirewall = false` and root login off, remote access is Tailscale-only, and
the one WPA-EAP identity lives outside the repo. What the public tree leaks is a
*profile*, not a secret, and a profile only becomes targetable when joined to a
reachable address — which the config never publishes. Issues are where that
second column would appear, so they are the half worth closing.

## Considered options

- **Keep issues as markdown under `.scratch/`.** Zero setup, greppable, and
  private by default. Rejected as the general case because a global ignore rule
  covers `.scratch/`, so 26 tickets existed on exactly one machine in one
  worktree, with no history and no backup — an odd failure for a repo whose
  purpose is rebuilding a machine from nothing. Retained for one narrow case;
  see Consequences.
- **Flip `nixos-config` private.** Solves the exposure completely. Rejected
  because it spends the portfolio listing and easy sharing, which are the
  repo's recurring benefits, and because a bootstrap repo you cannot clone
  without credentials is worse at its job: a fresh install would need `gh auth`
  before it could fetch the config that sets up its own keys.
- **A private duplicate of the whole repo, issues there.** Rejected: GitHub
  forks inherit the parent's visibility, so this means a second copy of the code
  that diverges the first time a push goes to the wrong remote. An issues-only
  repo has nothing to diverge.
- **Self-hosted Forgejo.** The intended end state, deferred rather than
  rejected. It needs a homelab that does not exist yet — all 13 homelab
  decisions are still open, including which machine is always-on. Forgejo's
  importer carries issues, comments, labels and milestones across when the time
  comes, so this decision does not foreclose it.

## Consequences

- `gh` infers its repo from `git remote -v`, which resolves to `nixos-config`.
  Every tracker command must pass `--repo HefKer/nixos-issues` explicitly.
- Closing keywords do not cross repositories: a commit saying `Fixes #12` closes
  nothing. Issues are closed explicitly, quoting the SHA. A cross-repo mention
  still leaves a backlink, and renders as a dead reference to anyone without
  access — so a public commit can carry an issue number safely.
- `grep -r .scratch/` no longer finds every ticket on a topic; that becomes
  `gh issue list --search`, a network round-trip, and issue bodies no longer sit
  on disk beside the code they describe.
- **Efforts about the homelab stay in `.scratch/`**, permanently and including
  after Forgejo exists. Notes about infrastructure have to stay readable while
  that infrastructure is down, half-built, or being reinstalled, which is
  precisely when they are wanted. A tracker hosted on the homelab cannot
  describe its own bootstrap.
- ~~The 26 pre-existing local tickets are not migrated yet, so both places are
  live until they are.~~ Resolved 2026-09-12; see the Status log.

## Status log

Amendments to the state this decision describes. The sections above are the
record as written when the decision was taken and are not edited in place.

### 2026-09-12 — the pre-existing tickets are migrated

27 files across ten efforts became 27 issues in `HefKer/nixos-issues`, one
milestone per effort. `Status:` lines became labels, `Blocked by:` lines became
native dependency edges, and the four free-text status strings were mapped onto
canonical labels rather than copied. `.scratch/` is no longer a second place to
look for a ticket. The originals are kept as dead copies in
`~/nixos/.archive/scratch/`, which — unlike `.scratch/` — is Syncthing-
replicated; its README carries the file-to-issue mapping.

`.scratch/homelab/` stayed local as this ADR requires, and is now the only live
markdown effort.

### Open: the homelab tickets are still unbacked

The reason for keeping homelab tickets local is availability while the homelab
is down — but the copy that gives them that availability is also the only copy,
git-ignored and on one machine, which is the exact failure this ADR moved
everything else to escape. Staying out of a tracker and staying out of a backup
are separate things that `.scratch/` currently couples.

The candidate answer is to stop treating "local markdown" and "tracker issue" as
alternatives: keep the tracker as the source of truth and generate the markdown
from it on a schedule, so the offline copy is a rendering rather than a second
original. That is a decision about duplication, staleness and which side wins a
conflict, and it is not taken here — see `HefKer/nixos-issues#31`.
