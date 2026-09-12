# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the
codebase. Layout is **single-context**.

## Before exploring, read these

- **`CONTEXT.md`** at the repo root: the glossary for how system configuration, user
  configuration, and hand-edited dotfiles relate.
- **`docs/adr/`**: read the ADRs that touch the area you're about to work in.

If a file doesn't exist, proceed silently. `/domain-modeling` (reached via
`/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily, when a term or
a decision actually gets resolved.

## File structure

```
/
├── CONTEXT.md
├── docs/
│   ├── adr/
│   │   └── 0001-dotfiles-wired-by-home-manager-as-out-of-store-symlinks.md
│   └── agents/
├── hosts/
├── homes/
├── modules/
└── lib/
```

## Use the glossary's vocabulary

When your output names a domain concept (an issue title, a refactor proposal, a hypothesis, a
module name), use the term as `CONTEXT.md` defines it, including the synonyms its _Avoid_
lines rule out — write "home layer", not "HM layer"; "host", not "box".

If the concept you need isn't in the glossary, that's a signal: either you're inventing
language the project doesn't use (reconsider), or there's a real gap (note it for
`/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, say so rather than silently overriding it:

> _Contradicts ADR-0001 (dotfiles as out-of-store symlinks), but worth reopening because…_
