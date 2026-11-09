{
  dotfilesRoot,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  socks = "${osConfig.vpnNamespaces.proton.namespaceAddress}:1080";
  directList = "${dotfilesRoot}/proxy/direct.txt";

  # Privoxy uses the last forward rule that matches, so the tunnel default goes first.
  writeConfig = pkgs.writeShellApplication {
    name = "privoxy-config";
    runtimeInputs = [ pkgs.gnused ];
    text = ''
      config="$XDG_RUNTIME_DIR/privoxy.conf"
      {
        echo "listen-address 127.0.0.1:8118"
        echo "forward-socks5t / ${socks} ."
        echo "forward localhost ."
        echo "forward .ts.net ."
        for net in 10.*.*.* 127.*.*.* 192.168.*.*; do echo "forward $net/ ."; done
        for i in $(seq 16 31); do echo "forward 172.$i.*.*/ ."; done
        for i in $(seq 64 127); do echo "forward 100.$i.*.*/ ."; done
        if [[ -f ${directList} ]]; then
          sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' -e 's/^\.*/forward ./' -e 's/$/ ./' \
            ${directList}
        fi
      } >"$config.tmp"
      mv "$config.tmp" "$config"
    '';
  };
in
{
  systemd.user.services = {
    privoxy-config = {
      Unit.Description = "Write Privoxy's config from the direct-sites list";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe writeConfig;
      };
    };

    privoxy = {
      Unit = {
        Description = "Browser proxy out through Proton VPN, with direct exceptions";
        Requires = [ "privoxy-config.service" ];
        After = [ "privoxy-config.service" ];
      };
      Service = {
        ExecStart = "${lib.getExe pkgs.privoxy} --no-daemon %t/privoxy.conf";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };

  systemd.user.paths.privoxy-config = {
    Unit.Description = "Rewrite Privoxy's config when the direct-sites list changes";
    Path.PathChanged = [ directList ];
    Install.WantedBy = [ "default.target" ];
  };
}
