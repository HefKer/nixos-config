{
  config,
  lib,
  dotfilesRoot,
  ...
}:
let
  cfg = config.custom.home.dotfiles;

  # "mpv/.config/mpv" links to .config/mpv (package dir dropped); { source, target } names a per-host variant.
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

  # A store root (a deploy-only host) gets store copies; anything else stays editable in place (ADR-0001).
  linkSource =
    source:
    if lib.hasPrefix "${builtins.storeDir}/" dotfilesRoot then
      "${dotfilesRoot}/${source}"
    else
      config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/${source}";

  shared = layer [
    # The directory holds only config and themes; history and keys live in ~/.local/share/atuin.
    "atuin/.config/atuin"
    # The directory holds only projects.yaml; the queue and caches live in ~/.local/state/backlog.
    "backlog/.config/backlog"
    "btop/.config/btop"
    # ~/.claude holds Claude Code's runtime state, so its config links piece by piece; these dirs hold only scripts and commands.
    "claude/.claude/bin"
    "claude/.claude/commands"
    "claude/.claude/hooks"
    # Files beside that state, edited in place through the link; settings.json, which Claude Code itself rewrites, stays a synced real file.
    "claude/.claude/CLAUDE.md"
    "claude/.claude/keybindings.json"
    "claude/.claude/statusline.sh"
    "DankMaterialShell/.config/DankMaterialShell"
    # The shell reads ~/.config/dms, but its regenerated nvim colorscheme reads this path.
    {
      source = "DankMaterialShell/.config/DankMaterialShell";
      target = ".config/Dux Shell";
    }
    "fastfetch/.config/fastfetch"
    "fish/.config/fish"
    "fuzzel/.config/fuzzel"
    # The directory takes git's runtime state (credential-store's secrets, gitk's); git writes through the link.
    "git/.config/git/config"
    "git/.config/git/ignore"
    # The directory also holds herdr's sockets, session and logs; herdr writes this file in place, not by rename.
    "herdr/.config/herdr/config.toml"
    "herdr/.config/herdr/plugins/config/jhochenbaum.hunkdiff"
    # The directory holds only this file; herdr-auto-title reads it once at startup.
    "herdr/.config/herdr-auto-title/config.env"
    # The directory also holds hunk's state.json and extensions; hunk saves view preferences through the link.
    "hunk/.config/hunk/config.toml"
    # The directory also holds lazygit's state.yml and PR cache; lazygit never writes config.yml.
    "lazygit/.config/lazygit/config.yml"
    "marksman/.config/marksman"
    "mpv/.config/mpv"
    "niri/.config/niri"
    "nvim/.config/nvim"
    "qutebrowser/.config/qutebrowser"
    # The parent holds history and caches, which must not enter the dotfiles root.
    "qutebrowser/.local/share/qutebrowser/userscripts"
    # starship reads one file directly in ~/.config, so the link is the file, not a directory.
    "starship/.config/starship.toml"
    "swayimg/.config/swayimg"
    # The directory holds only config.toml; the page cache lives in ~/.cache/tealdeer.
    "tealdeer/.config/tealdeer"
    # The directory also holds session data and the DMS-generated themes/; Vesktop and Vencord write these in place, not by rename.
    "vesktop/.config/vesktop/settings.json"
    "vesktop/.config/vesktop/settings"
    "wezterm/.config/wezterm"
    "wlr-which-key/.config/wlr-which-key"
    # xdg-mime writes through the link; a tool saving by rename replaces it with a file that aborts the next rebuild.
    "xdg/.config/mimeapps.list"
    "xdg-desktop-portal-termfilechooser/.config/xdg-desktop-portal-termfilechooser"
    # The directory takes `ya pkg`'s package.toml, plugins and flavors, so installed packages land in the repo.
    "yazi/.config/yazi"
    {
      source = "scripts/qute-sandbox";
      target = ".local/bin/qute-sandbox";
    }
    {
      source = "scripts/session-find";
      target = ".local/bin/session-find";
    }
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
