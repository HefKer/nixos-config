{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation;
  # Root queries the drives daily; the user's health smart probe reads the findings file this writes.
  smartStatus = pkgs.writeShellApplication {
    name = "smart-status";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      smartmontools
    ];
    text = ''
      out=/var/lib/smart-status/findings
      next=$(mktemp "$out.XXXXXX")
      trap 'rm -f "$next"' EXIT
      smartctl --scan -j | jq -r '.devices[] | "\(.name)\t\(.type)"' | while IFS=$'\t' read -r dev type; do
        status=0
        j=$(smartctl -j -H -A -d "$type" "$dev") || status=$?
        # Bits 0-1: the drive couldn't be opened or queried (a USB bridge without SAT, say); nothing to judge.
        if [ $((status & 3)) != 0 ]; then continue; fi
        jq -r --arg dev "$dev" '
          (.model_name // "unknown model") as $m
          | (.nvme_smart_health_information_log // {}) as $n
          | ([.ata_smart_attributes.table[]? | {(.id | tostring): .raw.value}] | add // {}) as $a
          | [
              (select(.smart_status.passed == false) | "SMART health check failed"),
              (select(($n.critical_warning // 0) != 0) | "NVMe critical warning set"),
              (select(($n.media_errors // 0) > 0) | "NVMe media errors logged"),
              (select(($n.percentage_used // 0) >= 80) | "\(($n.percentage_used / 10 | floor) * 10)%+ of rated endurance used"),
              (select(($a["5"] // 0) > 0) | "reallocated sectors"),
              (select(($a["197"] // 0) > 0) | "sectors pending reallocation"),
              (select(($a["198"] // 0) > 0) | "uncorrectable sectors")
            ][]
          | "\($dev) (\($m)): \(.)"' <<<"$j"
      done >"$next"
      chmod 644 "$next"
      mv "$next" "$out"
      trap - EXIT
    '';
  };
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.smart-status = {
      description = "Write SMART findings for the health probes";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = lib.getExe smartStatus;
        StateDirectory = "smart-status";
      };
    };
    systemd.timers.smart-status = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        OnBootSec = "2min";
        Persistent = true;
      };
    };
  };
}
