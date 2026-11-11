{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  grim,
  slurp,
  wl-clipboard,
  libnotify,
  niri,
}:
# jev isn't a runtime input: it's ~/dots/scripts/jev, linked to ~/.local/bin and found on niri's PATH.
stdenvNoCC.mkDerivation {
  pname = "smart-shot";
  version = "0.1.0";
  src = ./smart-shot.py;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    install -Dm644 $src $out/share/smart-shot/smart-shot.py
    makeWrapper ${lib.getExe (python3.withPackages (ps: [ ps.pillow ]))} $out/bin/smart-shot \
      --add-flags $out/share/smart-shot/smart-shot.py \
      --prefix PATH : ${
        lib.makeBinPath [
          grim
          slurp
          wl-clipboard
          libnotify
          niri
        ]
      }
  '';
  meta.mainProgram = "smart-shot";
}
