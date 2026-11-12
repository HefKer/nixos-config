# new-project

<!-- One paragraph: what this is and who it is for. -->

## Build

`cargo run` in the devShell, `nix build` for the packaged app. After changing a dependency, commit `Cargo.lock`: `nix build` reads it.

## Domain docs

Single context: `GLOSSARY.md` and `docs/adr/` at the root, created when the first term or
decision needs one.
