{
  lib,
  stdenvNoCC,
  fetchzip,
  makeWrapper,
  python3,
  pipewire,
}:
let
  # Pinned voice packs from sherpa-onnx's tts-models release. Lessac's dataset is research-only; the flake fetches it, never ships it.
  voice =
    name: hash:
    fetchzip {
      url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/${name}.tar.bz2";
      inherit hash;
    };
  piper = voice "vits-piper-en_US-lessac-medium" "sha256-/iu4rTEC7716gmVcemQs4mHcChiyB0zadO4ikPNLzcs=";
  kokoro = voice "kokoro-en-v0_19" "sha256-Kjq29Rtn34qzkR06zG0JHR3P/eQdDUC6NPKn/WKqJs4=";
  python = python3.withPackages (ps: [ ps.sherpa-onnx ]);
in
stdenvNoCC.mkDerivation {
  pname = "say";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  doCheck = true;
  nativeCheckInputs = [ python3 ];
  checkPhase = ''
    runHook preCheck
    python3 test.py say.py
    runHook postCheck
  '';
  installPhase = ''
    install -Dm644 say.py $out/share/say/say.py
    makeWrapper ${lib.getExe python} $out/bin/say \
      --add-flags $out/share/say/say.py \
      --set SAY_PIPER ${piper} \
      --set SAY_KOKORO ${kokoro} \
      --prefix PATH : ${lib.makeBinPath [ pipewire ]}
  '';
  passthru = { inherit piper kokoro; };
  meta.mainProgram = "say";
}
