{
  config,
  lib,
  pkgs,
  consts,
  ...
}:
let
  cfg = config.custom.roles.workstation.virtualization;
  inherit (consts) username;
in
{
  config = lib.mkIf cfg.enable {
    # libvirtd fronts QEMU/KVM: KVM runs the CPU in-kernel, QEMU emulates the devices, libvirt gives one API.
    virtualisation.libvirtd = {
      enable = true;

      qemu = {
        # OVMF (guest UEFI + Secure Boot) ships by default; swtpm adds the software TPM 2.0 Windows 11 requires.
        swtpm.enable = true;
      };
    };

    # virt-manager: GTK GUI to create, boot, and console into VMs.
    programs.virt-manager.enable = true;

    # dconf stores virt-manager's UI/connection settings; it needs the daemon.
    programs.dconf.enable = true;

    # Let the SPICE console forward host USB devices into the running guest.
    virtualisation.spiceUSBRedirection.enable = true;

    # `libvirtd` membership manages qemu:///system without sudo; merges with core/users.nix.
    users.users.${username}.extraGroups = [ "libvirtd" ];

    environment.systemPackages = with pkgs; [
      virt-viewer # standalone SPICE/VNC console (remote-viewer)
      spice-gtk # SPICE client libs: guest clipboard + auto display resize
      virtiofsd # fast host<->guest shared folders (virtio-fs backend)
      virtio-win # Windows virtio drivers ISO, at /run/current-system/sw/share/virtio-win/virtio-win.iso; mount during install
    ];
  };
}
