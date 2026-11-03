{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bash,
  nodejs,
  yazi,
}:
stdenvNoCC.mkDerivation {
  pname = "herdr-yazi";
  version = "1.1.0-unstable-2026-08-19";

  src = fetchFromGitHub {
    owner = "speardragon";
    repo = "herdr-yazi";
    rev = "54aa4e6dff480189630fa3593146cdcc2768ade9";
    hash = "sha256-5bAy+xD1mLYJOUYvLWeU2pgZpYAeo+hxdNSlaM9pCkA=";
  };

  # herdr's PATH may lack bash, node and yazi; the [[build]] step only checks for yazi or brew-installs it.
  postPatch = ''
    sed -i '/^\[\[build\]\]$/,/^$/d' herdr-plugin.toml
    if grep -q '\[\[build\]\]' herdr-plugin.toml; then
      echo "[[build]] step still present" >&2
      exit 1
    fi
    substituteInPlace herdr-plugin.toml \
      --replace-fail 'command = ["bash", ' 'command = ["${lib.getExe bash}", ' \
      --replace-fail 'exec yazi' 'exec ${lib.getExe yazi}' \
      --replace-fail '$(bash ' '$(${lib.getExe bash} '
    substituteInPlace bin/resolve-dir.sh \
      --replace-fail '$(node -e ' '$(${lib.getExe nodejs} -e '
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir $out
    cp -r herdr-plugin.toml bin $out/
    runHook postInstall
  '';

  meta = {
    description = "Herdr plugin that opens yazi in a pane at the focused pane's directory";
    homepage = "https://github.com/speardragon/herdr-yazi";
    license = lib.licenses.mit;
  };
}
