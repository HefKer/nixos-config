{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bash,
  python3,
  git,
  coreutils,
  gnused,
  gnugrep,
  ncurses,
  lazygit,
  fzf,
}:
let
  toolPath = lib.makeBinPath [
    bash
    python3
    git
    coreutils
    gnused
    gnugrep
    ncurses
  ];
  bashExe = lib.getExe bash;
  pythonExe = lib.getExe python3;
in
stdenvNoCC.mkDerivation rec {
  pname = "herdr-lazygit";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "Crokily";
    repo = "herdr-lazygit";
    rev = "v${version}";
    hash = "sha256-G0Jmwhsw0aYx1lomdM4eXz5uDrbDh/WPeTA94wjzWvo=";
  };

  buildInputs = [
    bash
    python3
  ];

  # The [[build]] step downloads a private lazygit + fzf into bin/; $out/bin links nixpkgs' instead.
  postPatch = ''
    substituteInPlace herdr-plugin.toml \
      --replace-fail '[[build]]
    command = ["/bin/sh", "scripts/install-runtime.sh"]' "" \
      --replace-fail 'command = ["bash", ' 'command = ["${bashExe}", ' \
      --replace-fail 'exec bash ' 'exec ${bashExe} '
    for script in run-lazygit open-lazygit open-lazygit-tab settings-fzf ai-commit-pane; do
      substituteInPlace scripts/$script.sh --replace-fail 'set -euo pipefail' \
        'set -euo pipefail
    export PATH="${toolPath}''${PATH:+:$PATH}"'
    done
    substituteInPlace scripts/open-settings-pane.sh \
      --replace-fail 'bash $(shq "$settings_sh")' '${bashExe} $(shq "$settings_sh")' \
      --replace-fail 'restore_cmd="python3 ' 'restore_cmd="${pythonExe} '
    substituteInPlace scripts/open-ai-commit-pane.sh \
      --replace-fail 'bash $(shq "$commit_sh")' '${bashExe} $(shq "$commit_sh")' \
      --replace-fail 'restore_cmd="python3 ' 'restore_cmd="${pythonExe} '
    # fzf runs --preview through $SHELL, and this preview is bash syntax that fish rejects.
    substituteInPlace scripts/ai-commit-pane.sh \
      --replace-fail '--preview "$preview_cmd"' '--with-shell "${bashExe} -c" --preview "$preview_cmd"'
    substituteInPlace scripts/runtime-versions.sh \
      --replace-fail "LAZYGIT_VERSION='0.65.0'" "LAZYGIT_VERSION='${lazygit.version}'" \
      --replace-fail "FZF_VERSION='0.74.4'" "FZF_VERSION='${fzf.version}'"
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp -r herdr-plugin.toml lazygit-config.yml scripts $out/
    rm $out/scripts/install-runtime.sh
    ln -s ${lib.getExe lazygit} $out/bin/lazygit
    ln -s ${lib.getExe fzf} $out/bin/fzf
    runHook postInstall
  '';

  meta = {
    description = "Herdr plugin that opens lazygit in a sidebar pane, with AI-written commit messages";
    homepage = "https://github.com/Crokily/herdr-lazygit";
    license = lib.licenses.mit;
  };
}
