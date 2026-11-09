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
  netns = "proton";
  webuiPort = 8080;
  socksPort = 1080;
  downloads = "/srv/torrents";

  forwardPort = pkgs.writeShellApplication {
    name = "proton-port-forward";
    runtimeInputs = with pkgs; [
      curl
      gnused
      iptables
      libnatpmp
    ];
    text = ''
      # Proton's NAT-PMP gateway inside every WireGuard tunnel.
      gateway=10.2.0.1

      iptables -N port-forward 2>/dev/null || iptables -F port-forward
      iptables -C INPUT -i ${netns}0 -j port-forward 2>/dev/null ||
        iptables -I INPUT -i ${netns}0 -j port-forward

      current=""
      while true; do
        natpmpc -a 1 0 udp 60 -g "$gateway" >/dev/null
        port=$(natpmpc -a 1 0 tcp 60 -g "$gateway" |
          sed -n 's/^Mapped public port \([0-9]*\) protocol TCP.*/\1/p')
        if [[ -z $port ]]; then
          echo "no port mapped by $gateway" >&2
          exit 1
        fi

        if [[ $port != "$current" ]]; then
          iptables -F port-forward
          iptables -A port-forward -p tcp --dport "$port" -j ACCEPT
          iptables -A port-forward -p udp --dport "$port" -j ACCEPT
          curl --fail --silent --show-error \
            --retry 15 --retry-connrefused --retry-delay 2 \
            --data "json={\"listen_port\":$port}" \
            http://127.0.0.1:${toString webuiPort}/api/v2/app/setPreferences
          echo "forwarding port $port"
          current=$port
        fi

        sleep 45
      done
    '';
  };
in
{
  imports = [ inputs.vpn-confinement.nixosModules.default ];

  config = lib.mkIf cfg.enable {
    # A Proton WireGuard config for a P2P server with NAT-PMP on, one per host.
    sops.secrets.proton-wg = { };

    vpnNamespaces.${netns} = {
      enable = true;
      wireguardConfigFile = config.sops.secrets.proton-wg.path;
      portMappings =
        map
          (port: {
            from = port;
            to = port;
          })
          [
            webuiPort
            socksPort
          ];
    };

    services.qbittorrent = {
      enable = true;
      inherit webuiPort;
      serverConfig = {
        LegalNotice.Accepted = true;
        BitTorrent.Session.DefaultSavePath = downloads;
        Preferences.WebUI = {
          AlternativeUIEnabled = true;
          RootFolder = "${pkgs.vuetorrent}/share/vuetorrent";
          LocalHostAuth = false;
          AuthSubnetWhitelistEnabled = true;
          AuthSubnetWhitelist = "${config.vpnNamespaces.${netns}.bridgeAddress}/32";
        };
      };
    };

    systemd = {
      services = {
        ${netns} = {
          wantedBy = lib.mkForce [ ];
          unitConfig.StopWhenUnneeded = true;
        };

        qbittorrent = {
          wantedBy = lib.mkForce [ ];
          vpnConfinement = {
            enable = true;
            vpnNamespace = netns;
          };
          serviceConfig.UMask = "0002";
        };

        proton-socks = {
          description = "SOCKS5 proxy out through Proton VPN";
          wantedBy = [ "multi-user.target" ];
          vpnConfinement = {
            enable = true;
            vpnNamespace = netns;
          };
          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.microsocks} -i ${
              config.vpnNamespaces.${netns}.namespaceAddress
            } -p ${toString socksPort}";
            DynamicUser = true;
            Restart = "on-failure";
          };
        };

        qbittorrent-port-forward = {
          description = "Proton VPN port forwarding for qBittorrent";
          wantedBy = [ "qbittorrent.service" ];
          partOf = [ "qbittorrent.service" ];
          after = [ "qbittorrent.service" ];
          vpnConfinement = {
            enable = true;
            vpnNamespace = netns;
          };
          serviceConfig = {
            ExecStart = lib.getExe forwardPort;
            Restart = "on-failure";
            RestartSec = 10;
          };
        };
      };

      tmpfiles.settings.torrents.${downloads}.d = {
        mode = "0775";
        user = "qbittorrent";
        group = "qbittorrent";
      };
    };

    users.users.${consts.username}.extraGroups = [ "qbittorrent" ];

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "qbittorrent.service" &&
            subject.user == "${consts.username}") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
