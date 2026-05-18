{
  config,
  lib,
  pkgs,
  inputs,
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
      printing.enable = true;
      # noctalia
      # power-profiles-daemon.enable = true;
      # upower.enable = true;
    };
    networking.networkmanager.enable = true;

    environment.systemPackages = with pkgs; [
      # --- Terminal Utils ---
      wezterm
      atuin
      fastfetch
      fzf
      eza
      proton-vpn-cli
      starship
      stow
      yazi
      python313Packages.youtube-transcript-api
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

      # --- GUI Applications ---
      nautilus
      obsidian
      vesktop
      discord
      signal-desktop
      teams-for-linux
      super-productivity
      spotify
      #spotifyd
      #ncspot
      cheese
      kdePackages.kdeconnect-kde

      # Image manipulation
      inkscape
      pinta
      # ksnip

      # Documents
      zathura
      onlyoffice-desktopeditors
      xwayland-satellite # req by onlyoffice

      # --- TUIs ---
      btop
      impala # wifi
      bluetui
      kalker # calculator

      # --- cool stuff ---
      ani-cli
      tint

      # --- browsers ---
      brave
      inputs.helium.packages.${system}.default

      # qutebrowser
      qutebrowser # https://github.com/nixos/nixpkgs/issues/508998
      ranger
      rbw # rust bitwarden
      pinentry-curses
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
      kdeconnect.enable = true;
      gnupg.agent = {
        # for rbw
        enable = true;
        pinentryPackage = pkgs.pinentry-curses;
        # pinentryPackage = pkgs.pinentry-gnome3;
        # pinentryPackage = pkgs.pinentry-qt;
      };
      dms-shell = {
        enable = true;

        systemd = {
          enable = true;
          restartIfChanged = true;
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
        liberation_ttf
        noto-fonts
        corefonts # Arial, Times New Roman, etc.
        vista-fonts # Calibri, Cambria, etc.
        google-fonts # Good general coverage
        noto-fonts-color-emoji
        nerd-fonts.jetbrains-mono
      ];

      fontconfig.defaultFonts = {
        monospace = [ "JetBrainsMono Nerd Font" ];
      };
    };

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
