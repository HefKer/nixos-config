{ config, pkgs, ... }:

{
  # === Slowly modularizing this file ===

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # noctalia
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;

  # Configure keymap in X11
  #services.displayManager.dms-greeter = {
  #enable = true;
  #compositor.name = "niri";  # Or "hyprland" or "sway"
  #};

  # Keybinds
  services.xserver = {
    enable = true;
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Terminal stuff
    wget
    tree-sitter
    evtest
  ];
  # Other programs:
  # pinta - img editing
  # obs, kdenlive
  # document viewer, xournal++

  environment.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
  };

  security.sudo.extraConfig = ''
    Defaults env_keep += "TERM COLORTERM TERMINFO"
  '';

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
