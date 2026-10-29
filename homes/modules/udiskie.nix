let
  # Filesystem UUIDs from `lsblk -f`; every other drive waits for a click.
  automountUuids = [
    "6DF6-6099" # BACKUP_2TB
  ];
in
{
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto";
    settings = {
      # First matching rule wins, so the catch-all goes last.
      device_config =
        map (uuid: {
          id_uuid = uuid;
          automount = true;
        }) automountUuids
        ++ [ { automount = false; } ];
      # udiskie drops the notification's Mount button when automount is on.
      notification_actions.device_added = [ "mount" ];
    };
  };
}
