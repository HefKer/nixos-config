{
  dms,
  jq,
  pipewire,
  wireplumber,
  writeShellApplication,
}:
writeShellApplication {
  name = "mic-mute-warn";
  # The jq filter is single-quoted on purpose; its $vars are jq's, not the shell's.
  excludeShellChecks = [ "SC2016" ];
  runtimeInputs = [
    dms
    jq
    pipewire
    wireplumber
  ];
  text = ''
    # Emits "old STREAM" for capture links in the first dump, "link STREAM SOURCE APP" for later ones, and "gone ID" for removed objects.
    filter='
      # A change may repeat only some props, so each update merges into what is known.
      def app_name: .info.props."application.name" // .info.props."application.process.binary";
      def node_info: {
        class: .info.props."media.class",
        passive: (.info.props."node.passive" | if . == null then null else tostring != "false" end),
        client: .info.props."client.id",
        name: app_name
      };
      foreach inputs as $dump ({n: 0, nodes: {}, clients: {}};
        .n += 1
        | reduce ($dump[] | select(.info == null)) as $o (.; del(.nodes[$o.id | tostring], .clients[$o.id | tostring]))
        | reduce ($dump[] | select(.info != null and .type == "PipeWire:Interface:Node")) as $o (.; .nodes[$o.id | tostring] += ($o | node_info | with_entries(select(.value != null))))
        | reduce ($dump[] | select(.info != null and .type == "PipeWire:Interface:Client")) as $o (.;
            .clients[$o.id | tostring] = (($o | app_name) // .clients[$o.id | tostring]));
        . as $s | $dump[]
        | if .info == null then "gone \(.id)"
          elif .type == "PipeWire:Interface:Link" then
            ($s.nodes[.info."input-node-id" | tostring]) as $in
            | ($s.nodes[.info."output-node-id" | tostring]) as $out
            # Monitors capture from a sink, so requiring an Audio/Source link leaves visualizers and screen-recording audio out.
            | select($in.class == "Stream/Input/Audio" and ($in.passive | not) and $out.class == "Audio/Source")
            | if $s.n == 1 then "old \(.info."input-node-id")"
              else "link \(.info."input-node-id") \(.info."output-node-id") \($in.name // $s.clients[$in.client | tostring] // "An app")" end
          else empty end)'

    declare -A seen=()
    # A stream links once per channel and again on each state change; only its first link is checked, so an open stream toasts at most once.
    while read -r kind stream source app; do
      case $kind in
        gone) unset "seen[$stream]" ;;
        old) seen[$stream]=1 ;;
        link)
          if [ -n "''${seen[$stream]-}" ]; then continue; fi
          seen[$stream]=1
          if [[ $(wpctl get-volume "$source" 2>/dev/null) == *MUTED* ]]; then
            # Dismissing first keeps an app's several streams from queueing a toast each.
            dms ipc call toast dismiss mic-mute-warn >/dev/null || true
            dms ipc call toast warnWith "$app: mic is muted" "" "" mic-mute-warn >/dev/null || true
          fi
          ;;
      esac
    done < <(pw-dump --monitor --no-colors | jq -n --unbuffered -r "$filter")
    # pw-dump ends when PipeWire goes away; failing lets systemd restart the watch against the new daemon.
    exit 1
  '';
}
