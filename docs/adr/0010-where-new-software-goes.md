# Where new software goes

Status: accepted

New software lands in one of three places, decided in this order:

1. **A project in `~/dev/<name>`** when it isn't about the user's machines
   (sites, games, mods, work) or it carries a build, versions or release
   cadence of its own. Having an audience is not the test on its own: the
   README's Worth stealing list already shares flake packages.
2. **A flake package in `pkgs/<name>`** when it is coupled to this setup (niri,
   herdr, hosts, paths), however large it grows. `backlog` is the case.
3. **A loose script in `~/dots/scripts/<name>`** when it is one file with no
   dependencies beyond what is installed and no tests, and is worth editing
   without a rebuild. Gaining a dependency, a test or a second file promotes it
   to a flake package.

Code that an app's own config runs (nvim lua, qutebrowser userscripts, herdr
local plugins) is part of that config and stays in the dotfiles root.

An agent asked to build something applies this rule. It states the placement
in one line, and it asks only when the tests disagree, such as a coupled tool
with a toolchain of its own. The `new-software` skill, shipped from this repo,
carries the rule and does the wiring for each place, so it reaches agents
working outside these two repos. The global `CLAUDE.md` stays free of it, so
that projects which don't need it aren't steered.

## Scaffolding a project

- This flake exports `templates.<lang>` (`python` with uv, `rust`, and `bare`,
  which has a devShell only). The skill runs `nix flake new -t`, then
  `setup-matt-pocock-skills` for the tracker, labels and domain docs.
- The baseline: git on `main`, a flake with a devShell and `packages.default`,
  `.envrc` with `use flake`, `AGENTS.md`, a `CLAUDE.md` holding `@AGENTS.md`,
  `README.md`, `CHANGELOG.md`. `GLOSSARY.md` and `docs/adr/` are created
  lazily, and a LICENSE is added when the repo goes public.
- The GitHub repo is created at scaffold time, and its visibility is asked
  each time. Issues live on the code repo. A private capture repo
  (`<name>-issues`) is created only for a public project the user wants to
  capture into unfiltered. The project is added to backlog's `projects.yaml`,
  followed by `backlog setup`.
- `~/dev` is flat by default. A `_group/` dir is used when the project joins an
  existing group, or makes a theme reach two or more projects.

## Graduation

A flake package or loose script that later passes test 1 graduates. Its history
is split out with `git subtree split` into `~/dev/<name>`, `pkgs/<name>` is
replaced by a flake input (as with `vc-*` and `qutewarden`), and its config
stays in the dotfiles root.

## Considered options

- **Audience as the test for a project.** Rejected: sharing already works from
  inside this repo, and splitting coupled tools out would cost a lock bump on
  every change, the cost [ADR-0009](0009-phone-work-lives-in-this-repo.md)
  avoided for phone tooling.
- **Every project gets a separate private issues repo**, as nixos, dots and
  SeatWatch have. Rejected: what forces the split is that capture refuses
  public repos, and that matters only for capture-heavy public projects.
- **The rule in the global `CLAUDE.md`.** Rejected: it would load into every
  project, including those it says nothing about. A skill loads only when the
  request matches.
- **A separate templates repo.** Rejected: there would be one more thing to
  host, and this flake's `nix flake check` already covers templates.

## Consequences

- The rule covers new work only. Existing drift (SeatWatch's issues repo,
  `CONTEXT.md` in all-in and SeatWatch, any `dots/scripts` breaking the
  one-file rule) is ticketed, not fixed in place.
- The skill and templates don't exist yet. Until they do, this ADR is the rule.
