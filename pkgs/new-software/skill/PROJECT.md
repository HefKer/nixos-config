# Project

1. **Confirm** the name (kebab-case) and its place in `~/dev`. `~/dev` is flat; a `_group/` dir (`_osu`, `_qute`) holds it when it joins that group, or when this project makes a theme reach two or more. Ask the GitHub visibility too, every time.
2. **Scaffold** from this flake's template, `python` (uv), `rust` or `bare` (an empty devShell, a shell script as `packages.default`):

   ```sh
   dir=~/dev/<group/><name> name=<name>
   nix flake new -t ~/nixos/main#<lang> "$dir" && cd "$dir"
   grep -rl 'new.project' . | xargs sed -i "s/new-project/$name/g; s/new_project/${name//-/_}/g"
   [ -d src/new_project ] && mv src/new_project "src/${name//-/_}"
   [ -f new-project.sh ] && mv new-project.sh "$name.sh"
   git init -b main && git add -A && nix run
   ```

   Done when `nix run` prints `hello from <name>`. Fill in the one-paragraph placeholders in `AGENTS.md` and `README.md`. `GLOSSARY.md`, `docs/adr/` and a LICENSE come later, when the first term, the first decision, or going public needs them.
3. **Commit** the scaffold, then create the repo: `gh repo create HefKer/<name> --private|--public --source . --push`.
4. **Agent skills**: run the `setup-matt-pocock-skills` skill in the project. Issues live on the project's own repo.
5. **Capture repo**: only for a public project the user wants to capture into unfiltered (ask when the project is public). Then `gh repo create HefKer/<name>-issues --private`, and the project's issue tracker doc points at it.
6. **Backlog**: add the project to `~/dots/backlog/.config/backlog/projects.yaml` (its header documents the fields). `repo` is the capture repo when there is one, else the project repo; a public project repo needs `public_ok: true`. Commit in `~/dots`, then run `backlog setup`.

Nothing to rebuild. Hand back the repo URL and the `projects.yaml` commit.
