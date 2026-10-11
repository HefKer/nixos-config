{
  config,
  lib,
  dotfilesRoot,
  ...
}:
let
  cfg = config.custom.home.dotfiles;

  # A bare entry's target is its source minus its package directory: "mpv/.config/mpv" -> .config/mpv.
  # A { source, target } pair gives one of several variants the canonical name.
  linkEntry =
    spec:
    if builtins.isString spec then
      {
        name = lib.concatStringsSep "/" (lib.drop 1 (lib.splitString "/" spec));
        value = spec;
      }
    else
      {
        name = spec.target;
        value = spec.source;
      };

  layer = entries: lib.listToAttrs (map linkEntry entries);

  # A store root (a deploy-only host) gets store copies; anything else stays editable in place, deliberately (ADR-0001).
  linkSource =
    source:
    if lib.hasPrefix "${builtins.storeDir}/" dotfilesRoot then
      "${dotfilesRoot}/${source}"
    else
      config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/${source}";

  shared = layer [
    "DankMaterialShell/.config/DankMaterialShell"
    "fish/.config/fish"
    # The directory takes git's runtime state (credential-store's secrets, gitk's); git writes through the link.
    "git/.config/git/config"
    "git/.config/git/ignore"
    # The directory also holds herdr's sockets, session and logs; herdr writes this file in place, not by rename.
    "herdr/.config/herdr/config.toml"
    "mpv/.config/mpv"
    "niri/.config/niri"
    "nvim/.config/nvim"
    "qutebrowser/.config/qutebrowser"
    # The parent holds history and caches, which must not enter the dotfiles root.
    "qutebrowser/.local/share/qutebrowser/userscripts"
    "wezterm/.config/wezterm"
  ];

  hosts = {
    desktop = layer [
      {
        source = "niri/host/desktop.kdl";
        target = ".config/niri-host.kdl";
      }
    ];
    lenovo = layer [
      {
        source = "niri/host/lenovo.kdl";
        target = ".config/niri-host.kdl";
      }
    ];
  };

  # `//`, not recursiveUpdate: a later layer's entry replaces an earlier one for the same target.
  links = shared // hosts.${cfg.host};
in
{
  options.custom.home.dotfiles = with lib; {
    enable = mkEnableOption "linking dotfiles from the dotfiles root into $HOME";

    host = mkOption {
      type = types.enum [
        "desktop"
        "lenovo"
      ];
      description = "The host this home is built for, which picks its per-host dotfiles.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.mapAttrs (_: source: { source = linkSource source; }) links;
  };
}
