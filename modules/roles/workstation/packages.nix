{
  config,
  lib,
  pkgs,
  inputs,
  consts,
  ...
}:
let
  cfg = config.custom.roles.workstation;
in
{
  config = lib.mkIf cfg.enable {
    users.users.${consts.username}.shell = pkgs.fish;

    nixpkgs.overlays = [
      # Enables DRM in qutebrowser
      (final: prev: { qutebrowser = prev.qutebrowser.override { enableWideVine = true; }; })
      # CiscoCollabHost re-execs argv[0], which execve can't resolve if it's a bare name from PATH
      (final: prev: {
        webex = prev.webex.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];
          postFixup = (old.postFixup or "") + ''
            rm "$out/bin/webex"
            makeWrapper "$out/opt/Webex/bin/CiscoCollabHost" "$out/bin/webex" \
              --argv0 "$out/opt/Webex/bin/CiscoCollabHost"
          '';
        });
      })
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
      wiremix
      wl-clipboard

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
      zoom-us
      super-productivity
      spotify
      cheese
      kdePackages.kdeconnect-kde
      zapzap # Whatsapp
      qbittorrent
      webex
      czkawka
      moonlight-qt

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
      inputs.pyroclear.packages.${stdenv.hostPlatform.system}.default

      # --- browsers ---
      brave
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
      kdeconnect.enable = true;
      obs-studio.enable = true;
      gnupg.agent = {
        # for rbw
        enable = true;
        pinentryPackage = pkgs.pinentry-curses;
      };
    };
  };
}
