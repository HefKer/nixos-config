{
  config,
  lib,
  dotfilesRoot,
  ...
}:
let
  cfg = config.custom.home.dotfiles;

  # A bare entry's target is its source minus stow's package directory: "mpv/.config/mpv" -> .config/mpv.
  stowEntry = source: {
    name = lib.concatStringsSep "/" (lib.drop 1 (lib.splitString "/" source));
    value = source;
  };

  # A store root (a deploy-only host) gets store copies; anything else stays editable in place.
  linkSource =
    source:
    if lib.hasPrefix "${builtins.storeDir}/" dotfilesRoot then
      "${dotfilesRoot}/${source}"
    else
      config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/${source}";

  links = lib.listToAttrs (
    map stowEntry [
      "DankMaterialShell/.config/DankMaterialShell"
      "fish/.config/fish"
      "mpv/.config/mpv"
      "niri/.config/niri"
      "nvim/.config/nvim"
      "qutebrowser/.config/qutebrowser"
      # The parent holds history and caches, which must not enter the dotfiles root.
      "qutebrowser/.local/share/qutebrowser/userscripts"
      "wezterm/.config/wezterm"
    ]
  );
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
