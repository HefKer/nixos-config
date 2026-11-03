{
  lib,
  rustPlatform,
  fetchFromGitHub,
  bash,
  dtach,
}:
rustPlatform.buildRustPackage {
  pname = "herdr-floax";
  version = "0.3.1-unstable-2026-10-23";

  src = fetchFromGitHub {
    owner = "Tyru5";
    repo = "herdr-floax";
    rev = "0e9d9545dde074dcb4f200029178261f5c28b31f";
    hash = "sha256-Gp9uv6bDuyQeJSshFeJF00uF09cWHwboQ5uKN7K9CF8=";
  };

  cargoHash = "sha256-MC1S8e/6DD5oVMKdB7UzLt6x++CxjIyN8dU0tree6EE=";

  # The script is run by path from the plugin root, and herdr's PATH may have neither bash nor dtach.
  postPatch = ''
    substituteInPlace src/main.rs \
      --replace-fail 'CommandBuilder::new("bash")' 'CommandBuilder::new("${lib.getExe bash}")'
    substituteInPlace scripts/floating-shell.sh \
      --replace-fail 'bin="''${HERDR_PLUGIN_ROOT:-.}/target/release/herdr-floax"' "bin=$out/bin/herdr-floax" \
      --replace-fail 'command -v dtach' 'command -v ${lib.getExe dtach}' \
      --replace-fail 'exec dtach ' 'exec ${lib.getExe dtach} '
    substituteInPlace herdr-plugin.toml \
      --replace-fail '"./target/release/herdr-floax"' "\"$out/bin/herdr-floax\""
    sed -i '/^# Build the pane binary/,/^command = \["cargo"/d' herdr-plugin.toml
  '';

  nativeCheckInputs = [ bash ];
  # portable-pty starts children in $HOME.
  preCheck = "export HOME=$(mktemp -d)";

  # Needs a live herdr server.
  checkFlags = [ "--skip=picker_keeps_selected_pane_fullscreen_after_teardown" ];

  postInstall = ''
    install -Dm644 herdr-plugin.toml -t $out
    install -Dm755 scripts/floating-shell.sh -t $out/scripts
  '';

  meta = {
    description = "Herdr plugin that toggles a floating scratch shell per workspace, after tmux-floax";
    homepage = "https://github.com/Tyru5/herdr-floax";
    license = lib.licenses.mit;
    mainProgram = "herdr-floax";
  };
}
