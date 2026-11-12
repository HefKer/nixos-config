# new-project

<!-- One paragraph: what this is and who it is for. -->

## Build

Python with uv: `uv add <dep>` for a dependency, then add its nixpkgs `python3Packages` attribute to `dependencies` in `flake.nix` so `nix build` has it too; `uv run new-project` to run, `nix build` for the packaged app (`packages.default` builds from `pyproject.toml`).

## Domain docs

Single context: `GLOSSARY.md` and `docs/adr/` at the root, created when the first term or
decision needs one.
