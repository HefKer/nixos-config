{
  config,
  dotfilesRoot,
  pkgs,
  ...
}:
let
  keymapDir = "${dotfilesRoot}/kanata";
  svg = "${config.xdg.cacheHome}/kanata-keymap/keymap.svg";

  # keymap-drawer otherwise downloads this at draw time.
  layout = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/qmk/qmk_firmware/4791cfae1af0bc15a0bd8417c5195bf482b87605/layouts/default/60_ansi/info.json";
    hash = "sha256-/nkxw7F2i69HlZqWA0M3v6ICWCVKenBr/QW4mQL2FWw=";
  };

  render = pkgs.writeShellApplication {
    name = "kanata-keymap-render";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
      pkgs.keymap-drawer
    ];
    text = ''
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
      # keymap-drawer picks its layout by the key names in defsrc and deflayermap, and its 60% has grv where the Wooting has esc; only a key position starts a line.
      sed 's/^\(\s*\)esc /\1grv /' ${keymapDir}/keymap.kbd > "$tmp/keymap.kbd"
      keymap -c ${keymapDir}/keymap-drawer.yaml parse -k "$tmp/keymap.kbd" -o "$tmp/keymap.yaml"
      keymap -c ${keymapDir}/keymap-drawer.yaml draw -j ${layout} "$tmp/keymap.yaml" -o "$tmp/keymap.svg"
      mkdir -p "$(dirname ${svg})"
      mv "$tmp/keymap.svg" ${svg}
    '';
  };

  # Toggled from niri's Mod+/ bind; the app id is what its floating window rule matches.
  viewer = pkgs.writeShellApplication {
    name = "kanata-keymap";
    runtimeInputs = [
      pkgs.procps
      pkgs.swayimg
    ];
    text = ''
      pkill -f -- '--appid=kanata-keymap' || exec swayimg --appid=kanata-keymap ${svg}
    '';
  };
in
{
  home.packages = [ viewer ];

  systemd.user.services.kanata-keymap-render = {
    Unit.Description = "Draw the kanata keymap for the keymap viewer";
    Service = {
      Type = "oneshot";
      ExecStart = "${render}/bin/kanata-keymap-render";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.paths.kanata-keymap-render = {
    Unit.Description = "Redraw the kanata keymap when it changes";
    Path.PathChanged = [
      "${keymapDir}/keymap.kbd"
      "${keymapDir}/keymap-drawer.yaml"
    ];
    Install.WantedBy = [ "default.target" ];
  };
}
