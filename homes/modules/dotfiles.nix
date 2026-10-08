{
  config,
  lib,
  dotfilesRoot,
  ...
}:
let
  cfg = config.custom.home.dotfiles;

  # A bare entry names its source under the dotfiles root; the target is that path minus the
  # package directory stow used, e.g. "mpv/.config/mpv" -> ~/.config/mpv.
  entry = source: {
    name = lib.concatStringsSep "/" (lib.drop 1 (lib.splitString "/" source));
    value = source;
  };

  # A store root (a deploy-only host) gets store copies; anything else stays editable in place.
  link =
    source:
    if lib.hasPrefix "${builtins.storeDir}/" dotfilesRoot then
      "${dotfilesRoot}/${source}"
    else
      config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/${source}";

  links = lib.listToAttrs (map entry [ ]);
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

    links = mkOption {
      type = types.attrsOf types.str;
      default = optionalAttrs cfg.enable links;
      internal = true;
      readOnly = true;
      description = "The link set: each $HOME-relative target mapped to its source under the dotfiles root.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        # A path literal is copied into the store under flakes, silently making every link immutable.
        assertion = builtins.isString dotfilesRoot;
        message = "dotfilesRoot must be a string, not a Nix path literal (ADR-0001)";
      }
    ];

    home.file = lib.mapAttrs (_: source: { source = link source; }) links;
  };
}
