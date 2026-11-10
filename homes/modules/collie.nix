{
  config,
  lib,
  pkgs,
  inputs,
  osConfig,
  ...
}:
let
  collie = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.collie;
  root = "${collie}/lib/collie";
  herdrConfig = "${config.xdg.configHome}/herdr";
  pluginConfig = "${herdrConfig}/plugins/config/herdr.collie";
  # `collie start` bakes the tailnet hosts into the unit; this finds them at each start instead.
  bridge = pkgs.writeShellApplication {
    name = "collie-bridge";
    runtimeInputs = [
      osConfig.services.tailscale.package
      pkgs.jq
    ];
    text = ''
      hosts=$(tailscale status --json | jq -r '[(.Self.DNSName | rtrimstr(".")), (.Self.TailscaleIPs[] | if contains(":") then "[\(.)]" else . end)] | join(",")')
      # The bridge's Host gate refuses everything on an empty list, so fail and let systemd retry.
      [ -n "$hosts" ] || exit 1
      export COLLIE_TAILSCALE_HOSTS="$hosts"
      exec ${root}/bin/collie _exec-bridge
    '';
  };
in
{
  # Replaces the unit `collie start` writes, which pins one store path and so outlives upgrades.
  systemd.user.services.collie = {
    Unit = {
      Description = "Collie";
      After = [ "default.target" ];
      StartLimitIntervalSec = 0;
    };
    Service = {
      Type = "simple";
      WorkingDirectory = root;
      ExecStart = lib.getExe bridge;
      Restart = "on-failure";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateTmp = true;
      Environment = [
        "HERDR_SOCKET_PATH=${herdrConfig}/herdr.sock"
        "COLLIE_PORT=8787"
        "HERDR_PLUGIN_CONFIG_DIR=${pluginConfig}"
        "COLLIE_PLUGIN_ROOT=${root}"
      ];
      EnvironmentFile = "-${pluginConfig}/.env";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
