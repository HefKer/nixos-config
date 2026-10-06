{ lib, ... }:
{
  imports = [
    ./libvirt.nix
  ];

  options.custom.roles.workstation.virtualization = with lib; {
    enable = mkEnableOption "the virtualization sub-role (libvirt/QEMU/KVM)";
  };
}
