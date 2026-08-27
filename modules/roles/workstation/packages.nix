{
  config,
  lib,
  pkgs,
  inputs,
  consts,
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
    users.users.${consts.username}.shell = pkgs.fish;

    # consider moving these later
    services = {
      xserver.enable = true; # xkb, libinput, nvidia driver attach
      printing.enable = true;

      displayManager.sddm = {
        enable = true;
        wayland.enable = true;
      };
      xserver.displayManager.lightdm.enable = lib.mkForce false;
      gnome.gnome-keyring.enable = true; # req by niri's secret portal
    };
    networking.networkmanager.enable = true;

    nixpkgs.overlays = [
      # Enables DRM in qutebrowser
      (final: prev: { qutebrowser = prev.qutebrowser.override { enableWideVine = true; }; })
    ];

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
      kanata
      rclone
      yq
      translate-shell # `def` fish func: dict/translate lookups
      oscclip # osc-copy/osc-paste: pipe to local clipboard over SSH via OSC 52

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
      signal-desktop
      teams-for-linux
      super-productivity
      spotify
      cheese
      kdePackages.kdeconnect-kde
      zapzap # Whatsapp
      qbittorrent
      webex

      # Image manipulation
      inkscape
      pinta

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
      google-chrome # for claudio
      inputs.helium.packages.${stdenv.hostPlatform.system}.default
      inputs.zen-browser.packages.${stdenv.hostPlatform.system}.default

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
