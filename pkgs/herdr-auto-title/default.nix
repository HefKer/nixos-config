{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "herdr-auto-title";
  version = "0.19.0";

  src = fetchFromGitHub {
    owner = "kryptamine";
    repo = "herdr-auto-title";
    rev = "v${version}";
    hash = "sha256-HfZqth8aFy05KkSPAyWCJKKtAQanVZMrU+6rRVCRgcg=";
  };

  vendorHash = "sha256-QxFp1b7pf7bn3Hh0hyaj8ke5Z61N+WwjhHt3pFiapTs=";

  subPackages = [ "cmd/herdr-auto-title" ];

  # The plugin root is read-only in the store, so [[build]] can't place a binary there and herdr gets the store path instead.
  postPatch = ''
    substituteInPlace herdr-plugin.toml \
      --replace-fail 'platforms = ["linux", "macos", "windows"]' 'platforms = ["linux", "macos"]' \
      --replace-fail '[[build]]
    platforms = ["linux", "macos"]
    command = ["sh", "scripts/install.sh"]
    ' "" \
      --replace-fail '[[build]]
    platforms = ["windows"]
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "scripts/install.ps1"]
    ' "" \
      --replace-fail '[[startup]]
    platforms = ["windows"]
    command = ["./herdr-auto-title.exe"]
    ' "" \
      --replace-fail '"./herdr-auto-title"' '"${placeholder "out"}/bin/herdr-auto-title"'
  '';

  postInstall = ''
    cp herdr-plugin.toml $out/
  '';

  meta = {
    description = "Herdr plugin that names tabs and panes after what they hold";
    homepage = "https://github.com/kryptamine/herdr-auto-title";
    license = lib.licenses.mit;
    mainProgram = "herdr-auto-title";
  };
}
