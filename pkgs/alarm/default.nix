{
  coreutils,
  findutils,
  fuzzel,
  glib,
  jq,
  lib,
  libnotify,
  pipewire,
  procps,
  sound-theme-freedesktop,
  systemd,
  writeShellApplication,
  # The folder holding one file per alarm; Syncthing shares it between hosts.
  store,
}:
writeShellApplication {
  name = "alarm";
  runtimeInputs = [
    coreutils
    findutils
    fuzzel
    glib
    jq
    libnotify
    pipewire
    procps
    systemd
  ];
  text = ''
    store=${lib.escapeShellArg store}
    sound=${sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga
  ''
  + builtins.readFile ./alarm.sh;
}
