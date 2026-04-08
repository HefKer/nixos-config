{
  config,
  pkgs,
  ...
}:

{
  config = {
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
      mpv
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
    };

    fonts = {
      packages = with pkgs; [
        maple-mono.truetype
      ];
    };
  };
}
