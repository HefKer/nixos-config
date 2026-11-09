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
    environment.localBinInPath = true;

    # meme-add reads Klipy GIFs through Klipy's API, since its pages sit behind a Cloudflare bot check.
    sops.secrets.klipy-api = {
      sopsFile = ../../../secrets/shared.yaml;
      owner = consts.username;
    };

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
      yazi
      # mimeapps.list opens directories with this: yazi.desktop is Terminal=true, which xdg-open runs with no terminal, so yazi dies at once.
      (makeDesktopItem {
        name = "yazi-wezterm";
        desktopName = "Yazi (WezTerm)";
        icon = "yazi";
        exec = "wezterm start --always-new-process --class yazi -- yazi %f";
        mimeTypes = [ "inode/directory" ];
        categories = [
          "System"
          "FileManager"
        ];
        noDisplay = true;
      })
      mediainfo # yazi's "Show media info" opener
      exiftool # yazi's "Show EXIF" opener
      python313Packages.youtube-transcript-api
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
      trash-cli

      # --- Archiving & Compression ---
      unzip
      gzip

      # --- GUI Applications ---
      nautilus
      obsidian
      # Vencord from the store, with VcPresets, QuickActions (repo vc-actions) and VcShrink built in, rather than the copy Vesktop downloads.
      (vesktop.override {
        withSystemVencord = true;
        vencord = callPackage ../../../pkgs/vencord-userplugins {
          plugins = {
            vcPresets = inputs.vc-presets;
            vcActions = inputs.vc-actions;
            vcShrink = inputs.vc-shrink;
          };
        };
      })
      signal-desktop
      teams-for-linux
      zoom-us
      super-productivity
      cheese
      kdePackages.kdeconnect-kde
      zapzap # Whatsapp
      webex
      czkawka
      moonlight-qt
      slack
      # meme-pick/meme-add and sound-pick/sound-add/sound-stop/sound-volume, for niri's Mod+G and Mod+Ctrl+G binds.
      (callPackage ../../../pkgs/memes {
        library = "${consts.home}/memes";
        sink = "soundboard-in";
        klipyKey = config.sops.secrets.klipy-api.path;
      })
      # share-cast-target, which Vesktop's VcPresets runs to answer the Share Screen dialog unattended.
      (callPackage ../../../pkgs/share-cast-target { niri = config.programs.niri.package; })
      # window-pick, for niri's Mod+P: fuzzel over every open window.
      (callPackage ../../../pkgs/window-pick { })
      # Focuses or launches an app, cycling its windows on repeats, for niri's Mod+Alt summon binds.
      (callPackage ../../../pkgs/summon { })
      # For niri's per-window volume binds, on kanata's Fn2 a/s/d.
      (callPackage ../../../pkgs/window-volume { niri = config.programs.niri.package; })

      # Image manipulation
      inkscape
      pinta
      imv # image viewer
      wf-recorder # DMS Quick Capture's fallback recording backend, behind gpu-screen-recorder below
      psmisc # killall: how Quick Capture stops a recording
      libnotify # notify-send: Quick Capture's recording-saved and error notifications
      (tesseract.override { enableLanguages = [ "eng" ]; }) # Quick Capture's OCR tool (O in the editor) only reads English
      zbar # zbarimg: Quick Capture's QR scanner

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
      nss.tools # certutil: edit QtWebEngine's ~/.pki/nssdb trust store
      ranger
      rbw # rust bitwarden
      # Editing secrets, keyed through rbw
      sops
      age
      ssh-to-age
      inputs.qutewarden.packages.${stdenv.hostPlatform.system}.default
      pinentry-curses
      pinentry-qt
      rofi
      fuzzel
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
      gpu-screen-recorder.enable = true; # Quick Capture's preferred backend; unlike wf-recorder it records a whole monitor without asking which
      obs-studio = {
        enable = true;
        plugins = with pkgs.obs-studio-plugins; [
          obs-backgroundremoval
          obs-pipewire-audio-capture
        ];
      };
      gnupg.agent = {
        # for rbw
        enable = true;
        pinentryPackage = pkgs.pinentry-curses;
      };
    };

    systemd.user = {
      services.trash-empty = {
        description = "Empty trash deleted more than 30 days ago";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.trash-cli}/bin/trash-empty 30";
        };
      };
      timers.trash-empty = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
    };
  };
}
