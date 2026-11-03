{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
  hunk,
}:
buildNpmPackage rec {
  pname = "herdr-hunk-diff";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "jhochenbaum";
    repo = "herdr-hunk-diff";
    rev = "v${version}";
    hash = "sha256-aDsq1BKmaYl50HfqJywFZZxpVfmKGs1JHJyoMiRSnIM=";
  };

  npmDepsHash = "sha256-Gf1s4r43CPQaj+LgFJH3z82J2cYsIgZWUEVVJx8sJks=";
  inherit nodejs;

  # npm's hunk is a prebuilt binary for a generic glibc system and won't run on NixOS, and herdr's PATH may have no node.
  postPatch = ''
    substituteInPlace src/config.ts --replace-fail \
      'hunk: { bin: "auto",' 'hunk: { bin: "${lib.getExe hunk}",'
    substituteInPlace herdr-plugin.toml \
      --replace-fail 'command = ["node", ' 'command = ["${lib.getExe nodejs}", ' \
      --replace-fail 'exec node ' 'exec ${lib.getExe nodejs} '
  '';

  installPhase = ''
    runHook preInstall
    npm pkg delete dependencies.hunkdiff
    npm prune --omit=dev --no-save
    mkdir $out
    cp -r herdr-plugin.toml package.json dist node_modules skills $out/
    runHook postInstall
  '';

  meta = {
    description = "Herdr plugin that reviews agent-authored diffs in hunk and sends inline comments back to the agent";
    homepage = "https://github.com/jhochenbaum/herdr-hunk-diff";
    license = lib.licenses.mit;
  };
}
