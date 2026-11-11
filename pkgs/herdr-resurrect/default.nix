{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bash,
  fzf,
  jq,
  nodejs,
}:
stdenvNoCC.mkDerivation {
  pname = "herdr-resurrect";
  version = "0.2.0-unstable-2026-11-10";

  src = fetchFromGitHub {
    owner = "ntindle";
    repo = "herdr-resurrect";
    rev = "dab5bed632ccb28b480ae1bd601b4f60a41f66f1";
    hash = "sha256-KnCjJOQriC1d2FhP9Zx/m1aAinNNPSyHrm9+8959LKg=";
  };

  # herdr's PATH may have no node, fzf or jq. An agent pane is left to herdr's resume_agents_on_restore when agentResume is off, rather than relaunched fresh.
  postPatch = ''
    substituteInPlace herdr-plugin.toml \
      --replace-fail 'command = ["node", ' 'command = ["${lib.getExe nodejs}", ' \
      --replace-fail 'command = ["bash", ' 'command = ["${lib.getExe bash}", '
    substituteInPlace *-ui.sh \
      --replace-fail '"$(node ' '"$(${lib.getExe nodejs} '
    substituteInPlace open-space-ui.sh delete-space-ui.sh \
      --replace-fail 'command -v fzf ' 'command -v ${lib.getExe fzf} ' \
      --replace-fail '| fzf ' '| ${lib.getExe fzf} '
    substituteInPlace save-space.sh \
      --replace-fail 'command -v jq ' 'command -v ${lib.getExe jq} ' \
      --replace-fail '| jq ' '| ${lib.getExe jq} '
    substituteInPlace lib/restore.js --replace-fail \
      'if (resume) return resume;' 'if (resume || !require("./settings").load().agentResume) return resume;'
    # A store program's cmdline is a wrapper's unquoted args and a path GC can remove, so it relaunches by name.
    substituteInPlace lib/restore.js --replace-fail \
      '  if (pane.command && pane.command.restorable) {' \
      '  if (pane.command && pane.command.restorable) {
        if (String(pane.command.cmdline || "").startsWith("${builtins.storeDir}/")) return allowlist.baseName((pane.command.argv || [])[0] || pane.command.name);'
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir $out
    cp -r herdr-plugin.toml package.json bin lib config *.sh $out/
    runHook postInstall
  '';

  meta = {
    description = "Herdr plugin that snapshots panes' programs and agents and relaunches them after a restart";
    homepage = "https://github.com/ntindle/herdr-resurrect";
    license = lib.licenses.mit;
  };
}
