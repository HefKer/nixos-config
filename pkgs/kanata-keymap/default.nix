{
  coreutils,
  fetchurl,
  gnused,
  keymap-drawer,
  procps,
  swayimg,
  symlinkJoin,
  systemd,
  writeShellApplication,
}:
let
  svg = ''"''${XDG_CACHE_HOME:-$HOME/.cache}/kanata-keymap/keymap.svg"'';
  # niri's floating window rule for the viewer matches this.
  appId = "kanata-keymap";

  # keymap-drawer otherwise downloads this at draw time.
  layout = fetchurl {
    url = "https://raw.githubusercontent.com/qmk/qmk_firmware/4791cfae1af0bc15a0bd8417c5195bf482b87605/layouts/default/60_ansi/info.json";
    hash = "sha256-/nkxw7F2i69HlZqWA0M3v6ICWCVKenBr/QW4mQL2FWw=";
  };

  render = writeShellApplication {
    name = "kanata-keymap-render";
    runtimeInputs = [
      coreutils
      gnused
      keymap-drawer
    ];
    text = ''
      keymap_dir=$1
      svg=${svg}
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
      # keymap-drawer picks its layout by the key names in defsrc and deflayermap, and its 60% has grv where the Wooting has esc; an alias definition is followed by "(".
      sed 's/^\(\s*\)esc \(\s*[^ (]\)/\1grv \2/' "$keymap_dir/keymap.kbd" > "$tmp/keymap.kbd"
      keymap -c "$keymap_dir/keymap-drawer.yaml" parse -k "$tmp/keymap.kbd" -o "$tmp/keymap.yaml"
      keymap -c "$keymap_dir/keymap-drawer.yaml" draw -j ${layout} "$tmp/keymap.yaml" -o "$tmp/keymap.svg"
      mkdir -p "$(dirname "$svg")"
      mv "$tmp/keymap.svg" "$svg"
    '';
  };

  viewer = writeShellApplication {
    name = "kanata-keymap";
    runtimeInputs = [
      procps
      swayimg
      systemd
    ];
    text = ''
      svg=${svg}
      pkill -f -- 'swayimg(-wrapped)? --appid=${appId} ' && exit
      # Before the first render, or after a failed one, there is nothing to show yet.
      [ -e "$svg" ] || systemctl --user start kanata-keymap-render.service
      exec swayimg --appid=${appId} "$svg"
    '';
  };
in
symlinkJoin {
  name = "kanata-keymap";
  paths = [
    render
    viewer
  ];
  meta.mainProgram = "kanata-keymap";
}
