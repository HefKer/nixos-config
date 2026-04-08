{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      #./hardware-configuration.nix
    ];

  # Bootloader.

  #boot.loader = {
    #efi.canTouchEfiVariables = true;
    #timeout = 10;
#
    #systemd-boot = {
      #enable = true;
      #
      #extraEntries = {
        #"windows.conf" = ''
	  #title Windows
	  #efi /EFI/Microsoft/Boot/bootmgfw.efi
	  #sort-key y_windows
	#'';
      #};
#
    #};
#
  #};

  #boot.loader.systemd-boot.enable = false;
  #boot.loader.efi.canTouchEfiVariables = true;
  #boot.loader.grub.enable = true;
  #boot.loader.grub.devices = [ "nodev" ];
  #boot.loader.grub.efiSupport = true;
  #boot.loader.grub.useOSProber = true;

  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ "nodev" ];
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.useOSProber = false;
  boot.loader.grub.extraEntries = ''
    menuentry "Windows" {
      insmod part_gpt
      insmod fat
      insmod search_fs_uuid
      insmod chain
      sleep 5
      search --no-floppy --fs-uuid --set=root CE76-3D21
      chainloader /EFI/Microsoft/Boot/bootmgfw.efi
    }
  '';

  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

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

  # Enable bluetooth
  hardware.bluetooth.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  programs = {

      dms-shell = {
        enable = true;
      
        systemd = {
          enable = true;             # Systemd service for auto-start
          restartIfChanged = true;   # Auto-restart dms.service when dms-shell changes
        };
        
        # Core features
        enableSystemMonitoring = true;     # System monitoring widgets (dgop)
        enableVPN = true;                  # VPN management widget
        enableDynamicTheming = true;       # Wallpaper-based theming (matugen)
        enableAudioWavelength = true;      # Audio visualizer (cava)
        enableCalendarEvents = true;       # Calendar integration (khal)
      };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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

  #services.pipewire = {

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

}
