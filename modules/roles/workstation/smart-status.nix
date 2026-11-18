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
      gawk
      jq
      smartmontools
    ];
    text = ''
      out=/var/lib/smart-status/findings
      # "serial count" per drive: the media error count already accepted. A drive missing here is seeded with its current count.
      accepted=/var/lib/smart-status/media-errors
      touch "$accepted"
      next=$(mktemp "$out.XXXXXX")
      nextAccepted=$(mktemp "$accepted.XXXXXX")
      trap 'rm -f "$next" "$nextAccepted"' EXIT
      cp "$accepted" "$nextAccepted"
      smartctl --scan -j | jq -r '.devices[] | "\(.name)\t\(.type)"' | while IFS=$'\t' read -r dev type; do
        status=0
        j=$(smartctl -j -i -H -A -d "$type" "$dev") || status=$?
        # Bits 0-1: the drive couldn't be opened or queried (a USB bridge without SAT, say); nothing to judge.
        if [ $((status & 3)) != 0 ]; then continue; fi
        serial=$(jq -r '.serial_number // empty' <<<"$j")
        media=$(jq -r '.nvme_smart_health_information_log.media_errors // empty' <<<"$j")
        base=$media
        if [ -n "$serial" ] && [ -n "$media" ]; then
          seen=$(awk -v s="$serial" '$1 == s { print $2 }' "$accepted")
          if [ -n "$seen" ]; then base=$seen; else echo "$serial $media" >>"$nextAccepted"; fi
        fi
        jq -r --arg dev "$dev" --argjson base "''${base:-0}" --arg file "$accepted" '
          (.model_name // "unknown model") as $m
          | (.nvme_smart_health_information_log // {}) as $n
          | ([.ata_smart_attributes.table[]? | {(.id | tostring): .raw.value}] | add // {}) as $a
          | [
              (select(.smart_status.passed == false) | "SMART health check failed"),
              (select(($n.critical_warning // 0) != 0) | "NVMe critical warning set"),
              (select(($n.media_errors // 0) > $base) | "NVMe media errors rose \($base) → \($n.media_errors); accept by deleting its line in \($file)"),
              (select(($n.percentage_used // 0) >= 80) | "\(($n.percentage_used / 10 | floor) * 10)%+ of rated endurance used"),
              (select(($a["5"] // 0) > 0) | "reallocated sectors"),
              (select(($a["197"] // 0) > 0) | "sectors pending reallocation"),
              (select(($a["198"] // 0) > 0) | "uncorrectable sectors")
            ][]
          | "\($dev) (\($m)): \(.)"' <<<"$j"
      done >"$next"
      chmod 644 "$next"
      mv "$next" "$out"
      mv "$nextAccepted" "$accepted"
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
