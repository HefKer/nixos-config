{ inputs, pkgs, ... }:
{
  networking.networkmanager.enable = true;
  hardware.bluetooth.enable = true;

  security.rtkit.enable = true;
  services = {
    desktopManager.plasma6.enable = true;
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };

    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };
  };

  programs = {
    firefox.enable = true;
    neovim.enable = true;
  };

  environment.systemPackages = [
    pkgs.vesktop
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
  ];
}
