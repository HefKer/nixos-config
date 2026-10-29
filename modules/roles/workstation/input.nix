{
  config,
  lib,
  pkgs,
  consts,
  ...
}:
let
  cfg = config.custom.roles.workstation;

  # A dotfile, so `lrld` applies an edit without a rebuild (ADR-0005).
  keymapDir = "${config.home-manager.extraSpecialArgs.dotfilesRoot}/kanata";

  wooting = "Wooting Wooting 60HE (ARM)";
  # Its other interfaces carry no remappable keys, so neither instance grabs them.
  wootingInterfaces = map (suffix: "${wooting}${suffix}") [
    ""
    " System Control"
    " Consumer Control"
    " Mouse"
  ];
  # Unverified guesses: confirm against /proc/bus/input/devices with it plugged in.
  chorders = [
    "CharaChorder CharaChorder One"
    "CharaChorder CharaChorder One Keyboard"
    "CharaChorder CharaChorder Two"
    "CharaChorder CharaChorder Two Keyboard"
  ];

  quoted = lib.concatMapStringsSep " " (name: ''"${name}"'');

  # Every instance's defcfg beyond its devices; kanata-test simulates with the same.
  defcfg = "process-unmapped-keys yes";

  # A config holds one defcfg and an included file none, so all of it lives here.
  instance =
    name:
    { port, devices }:
    {
      inherit port;
      # Replaces the module's generated file, whose build-time --check can't see an include under $HOME.
      configFile = pkgs.writeText "kanata-${name}.kbd" ''
        (defcfg
          ${devices}
          ${defcfg}
          linux-continue-if-no-devs-found yes)

        (include ${keymapDir}/keymap.kbd)
      '';
    };

  instances = lib.mapAttrs instance {
    wooting = {
      port = 6661;
      devices = "linux-dev-names-include (${quoted [ wooting ]})";
    };
    other = {
      port = 6662;
      devices = "linux-dev-names-exclude (${quoted (wootingInterfaces ++ chorders)})";
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    services.xserver.xkb = {
      layout = "us";
      variant = ""; # Selects a sub-variant of the layout. "" = default. Other options (for "us"): "dvorak", "colemak", "altgr-intl", "intl", "mac", "workman"
    };

    users.users.${consts.username}.extraGroups = [
      "dialout" # Required by CharaChorder
      # use "tty" if "dialout" stops working
    ];

    services.kanata = {
      enable = true;
      keyboards = instances;
    };

    environment.systemPackages = [
      # The keymap viewer, for niri's Mod+/ bind; the home layer's render service draws what it shows.
      (pkgs.callPackage ../../../pkgs/kanata-keymap { })
      # kanata-flag for niri's Mod+Shift+. bind, and the keymap's tests.
      (pkgs.callPackage ../../../pkgs/kanata-misfires {
        inherit keymapDir defcfg;
        ports = lib.mapAttrs (_: instance: instance.port) instances;
      })
    ];

    # $HOME is 0700, closed to the dynamic user even with ProtectHome=read-only, so only the keymap is bound in.
    systemd.services = lib.mapAttrs' (
      name: _:
      lib.nameValuePair "kanata-${name}" {
        serviceConfig = {
          ProtectHome = lib.mkForce "tmpfs";
          BindReadOnlyPaths = [ keymapDir ];
          # Started mid-coldplug, it never grabs keyboards udev hadn't finished, nor finds its own output node.
          ExecStartPre = "-+${config.systemd.package}/bin/udevadm settle --timeout=30";
          Restart = "on-failure";
          RestartSec = 1;
        };
      }
    ) instances;
  };
}
