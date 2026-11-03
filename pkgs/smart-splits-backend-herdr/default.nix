{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bash,
  jq,
}:
stdenvNoCC.mkDerivation {
  pname = "smart-splits-backend-herdr";
  version = "0.1.0-unstable-2026-10-19";

  src = fetchFromGitHub {
    owner = "adriankarlen";
    repo = "smart-splits-backend-herdr";
    rev = "da1e50ae7bec7a7c2781aaf5a531eff350bdab20";
    hash = "sha256-dLWDAWvWvLT4pZepKj4f38pQGoQjo9UpQkCiAUeBkdU=";
  };

  # herdr's PATH may have no bash or jq; without jq the script silently stops passing keys through to Neovim.
  postPatch = ''
    substituteInPlace herdr-plugin.toml \
      --replace-fail 'command = ["bash", ' 'command = ["${lib.getExe bash}", '
    substituteInPlace scripts/herdr-navigate.sh \
      --replace-fail '#!/usr/bin/env bash' '#!${lib.getExe bash}' \
      --replace-fail 'command -v jq ' 'command -v ${lib.getExe jq} ' \
      --replace-fail '    jq -e ' '    ${lib.getExe jq} -e ' \
      --replace-fail '| jq -r ' '| ${lib.getExe jq} -r '
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir $out
    cp -r herdr-plugin.toml scripts LICENSE $out/
    runHook postInstall
  '';

  meta = {
    description = "Herdr plugin that moves between herdr panes and Neovim splits with the same keys, for smart-splits.nvim v3";
    homepage = "https://github.com/adriankarlen/smart-splits-backend-herdr";
    license = lib.licenses.mit;
  };
}
