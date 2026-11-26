{
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  watcher = pkgs.callPackage ../../pkgs/game-focus-watcher { };

  # From `niri msg windows` with each running; umu gives osu!stable, like any game without a Steam ID, steam_app_0.
  osu = [
    "osu!"
    "steam_app_0"
  ];
  # Its Steam id, and the class xremap matched it by.
  stardew = [
    "steam_app_413150"
    "Stardew Valley"
  ];
  # Games outside Steam, which have no steam_app_ id.
  nonSteamGames = [
    "io.mgba.mGBA"
    "net.kuribo64.melonDS"
  ];
  # App-id regexes (whole app-id) to kanata layers; the first match wins, so osu's steam_app_0 and Stardew come before Steam's.
  layers =
    map (id: [
      (lib.escapeRegex id)
      "passthrough"
    ]) osu
    # Native under Steam, so its id may be either; it needs its own layer for the animation cancel on Space.
    ++ map (id: [
      (lib.escapeRegex id)
      "stardew"
    ]) stardew
    ++ [
      [
        "steam_app_.*"
        "game"
      ]
    ]
    ++ map (id: [
      (lib.escapeRegex id)
      "game"
    ]) nonSteamGames;
  # Every layer-while-held layer in the keymap (fn1 on Caps, nav on Space, fn2), never taken for the layer to restore.
  heldLayers = [
    "fn1"
    "fn2"
    "nav"
  ];

  ports = lib.mapAttrsToList (_: keyboard: keyboard.port) osConfig.services.kanata.keyboards;
in
{
  systemd.user.services.game-focus-watcher = {
    Unit = {
      Description = "Switch kanata to a game's layer while that game is focused";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = lib.escapeShellArgs (
        [
          (lib.getExe watcher)
          "--niri"
          (lib.getExe osConfig.programs.niri.package)
        ]
        ++ lib.concatMap (layer: [ "--layer" ] ++ layer) layers
        ++ lib.concatMap (layer: [
          "--held-layer"
          layer
        ]) heldLayers
        ++ lib.concatMap (port: [
          "--port"
          (toString port)
        ]) ports
        # say holds non-urgent speech while this file exists; %t is $XDG_RUNTIME_DIR.
        ++ [
          "--state-file"
          "%t/game-focus"
        ]
      );
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
