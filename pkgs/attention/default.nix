{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  libnotify,
  niri,
  callPackage,
}:
# herdr, dms, wezterm and jev (~/.local/bin) come from the session's PATH, as for agent-notify in ~/dots.
stdenvNoCC.mkDerivation {
  pname = "attention";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  doCheck = true;
  nativeCheckInputs = [ python3 ];
  checkPhase = ''
    runHook preCheck
    HOME=$TMPDIR PYTHONPATH=. python3 -m unittest tests/test_attention.py
    runHook postCheck
  '';
  installPhase = ''
    install -Dm644 -t $out/share/attention/attention attention/*.py
    makeWrapper ${lib.getExe python3} $out/bin/attention \
      --add-flags "-m attention" \
      --prefix PYTHONPATH : $out/share/attention \
      --set ATTENTION_BIN $out/bin/attention \
      --prefix PATH : ${
        lib.makeBinPath [
          libnotify
          niri
          (callPackage ../repeat { })
        ]
      }
  '';
  meta.mainProgram = "attention";
}
