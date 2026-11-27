{
  imports = [
    ./boot.nix
    ./disks.nix
    ./hardware.nix
    ./session.nix
    ./users.nix
  ];

  system.stateVersion = "25.11";
  networking.hostName = "lat5430";

  custom.platform = "laptop";
}
