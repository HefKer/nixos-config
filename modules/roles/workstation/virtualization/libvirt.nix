{
  config,
  lib,
  pkgs,
  consts,
  ...
}:
let
  cfg = config.custom.roles.workstation.virtualisation;
  inherit (consts) username;
in
{
  options.custom.roles.workstation.virtualisation = with lib; {
    enable = mkEnableOption "libvirt/QEMU/KVM virtual machines via virt-manager";
  };

  config = lib.mkIf cfg.enable {
    # libvirtd is the management daemon in front of QEMU/KVM. KVM is the
    # in-kernel hypervisor (near-native speed); QEMU emulates the rest of the
    # machine (disk, nic, usb); libvirt gives them one stable API + XML config.
    virtualisation.libvirtd = {
      enable = true;

      qemu = {
        # OVMF is the open-source UEFI firmware for guests. The *Full* variant
        # is built with Secure Boot + TPM support, both mandatory to install
        # Windows 11. `.fd` exposes the flattened firmware files libvirt loads.
        ovmf = {
          enable = true;
          packages = [ pkgs.OVMFFull.fd ];
        };

        # swtpm emulates a TPM 2.0 chip in software and hands it to the guest.
        # Windows 11 refuses to install without a TPM 2.0 device present.
        swtpm.enable = true;
      };
    };

    # virt-manager: GTK GUI to create, boot, and console into VMs.
    programs.virt-manager.enable = true;

    # dconf stores virt-manager's UI/connection settings; it needs the daemon.
    programs.dconf.enable = true;

    # Let the SPICE console forward host USB devices into the running guest.
    virtualisation.spiceUSBRedirection.enable = true;

    # Membership in `libvirtd` lets the user manage the system libvirt instance
    # (qemu:///system) without sudo. This list merges with core/users.nix.
    users.users.${username}.extraGroups = [ "libvirtd" ];

    environment.systemPackages = with pkgs; [
      virt-viewer # standalone SPICE/VNC console (remote-viewer)
      spice-gtk # SPICE client libs: guest clipboard + auto display resize
      virtiofsd # fast host<->guest shared folders (virtio-fs backend)
      virtio-win # ISO of Windows virtio drivers; mount as a 2nd CD-ROM during
      # install so Windows can see the virtio disk/nic. Path:
      # /run/current-system/sw/share/virtio-win/virtio-win.iso
    ];
  };
}
