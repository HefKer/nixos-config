{
  jq,
  runCommandLocal,
  writeShellApplication,
  writeShellScriptBin,
}:
let
  summon = writeShellApplication {
    name = "summon";
    runtimeInputs = [ jq ];
    text = builtins.readFile ./summon.sh;
    passthru.tests = runCommandLocal "summon-tests" {
      nativeBuildInputs = [
        summon
        fakeNiri
        jq
      ];
    } (builtins.readFile ./tests.sh);
  };

  # Serves $WINDOWS as the window list and logs each action, so the tests need no compositor.
  fakeNiri = writeShellScriptBin "niri" ''
    if [ "$2" = --json ]; then cat "$WINDOWS"; else shift; echo "$*" >>"$LOG"; fi
  '';
in
summon
