{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation.packages;
in
{
  options.custom.roles.workstation.packages = with lib; {
    enable = mkEnableOption "Enable workstation packages";
  };

  config = lib.mkIf cfg.enable {
    # consider moving these later
    services = {
      xserver.enable = true;
      services.printing.enable = true;
      # noctalia
      power-profiles-daemon.enable = true;
      upower.enable = true;
    };
    networking.networkmanager.enable = true;

    environment.systemPackages = with pkgs; [
      wezterm
      atuin
      fastfetch
      fzf
      eza
      proton-vpn-cli
      starship

      # nnn # set up with home manaager

      # --- System Information & Diagnostics ---
      pciutils
      usbutils
      hwinfo
      kmon

      # --- Disk & Filesystem Utilities ---
      rsync
      os-prober

      # --- Archiving & Compression ---
      unzip
      gzip

      # --- Utilities ---
      stow
      # --- GUI Applications ---
      obsidian
      vesktop
      signal-desktop
      teams-for-linux
      super-productivity
      onlyoffice-desktopeditors
      xwayland-satellite # req by onlyoffice
      spotify
      #spotifyd
      #ncspot

      # --- TUIs ---
      btop
      impala
      bluetui

      # --- cool stuff ---
      ani-cli
      tint

      # --- browsers ---
      brave

      # qutebrowser
      qutebrowser
      bitwarden-cli
      python313Packages.tldextract
      python313Packages.pyperclip
      rofi
      yt-dlp
      (mpv.override {
        scripts = [
          mpvScripts.uosc
          mpvScripts.sponsorblock
        ];
      })
      #mpv-unwrapped

      # --- Virtualization ---
      libvirt
    ];

    programs = {
      git.enable = true;
      neovim.enable = true;
      fish.enable = true;
      zoxide.enable = true;
      bat.enable = true;
      lazygit.enable = true;
      pay-respects.enable = true;
      starship.enable = true;
      firefox.enable = true;
      localsend.enable = true;
      xwayland.enable = true; # required by onlyoffice

      dms-shell = {
        enable = true;

        systemd = {
          enable = true; # Systemd service for auto-start
          restartIfChanged = true; # Auto-restart dms.service when dms-shell changes
        };

        # Core features
        enableSystemMonitoring = true; # System monitoring widgets (dgop)
        enableVPN = true; # VPN management widget
        enableDynamicTheming = true; # Wallpaper-based theming (matugen)
        enableAudioWavelength = true; # Audio visualizer (cava)
        enableCalendarEvents = true; # Calendar integration (khal)
      };
    };

    fonts = {
      packages = with pkgs; [
        maple-mono.truetype
      ];
    };
  };
}
