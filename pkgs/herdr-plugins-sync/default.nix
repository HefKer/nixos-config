{
  lib,
  runCommandLocal,
  writeShellApplication,
  jq,
  yq-go,
  plugins,
}:
let
  # The fields herdr 0.9.5 requires per entry; it reads the rest from each manifest on every request.
  declared =
    runCommandLocal "herdr-plugins.json"
      {
        nativeBuildInputs = [
          jq
          yq-go
        ];
      }
      ''
        for root in ${lib.escapeShellArgs plugins}; do
          yq -p toml -o json "$root/herdr-plugin.toml" | jq --arg root "$root" '{
            plugin_id: .id, name, version, min_herdr_version,
            manifest_path: "\($root)/herdr-plugin.toml", plugin_root: $root,
            enabled: true, source: { kind: "local" }
          }'
        done | jq -s . > $out
      '';
in
writeShellApplication {
  name = "herdr-plugins-sync";
  runtimeInputs = [ jq ];
  text = ''
    registry=$1
    current='[]'
    if [ -e "$registry" ]; then
      current=$(jq . "$registry") || { echo "herdr-plugins-sync: $registry is not valid JSON, leaving it alone" >&2; exit 1; }
    fi

    # One entry missing a required field makes herdr drop every plugin, so check before writing.
    new=$(jq --slurpfile declared ${declared} '
      $declared[0] as $d
      | ($d | map(.plugin_id)) as $ids
      | (map({ (.plugin_id): .enabled }) | add // {}) as $was
      | map(select((.plugin_root | startswith("${builtins.storeDir}/") | not) and (.plugin_id as $id | $ids | index($id) | not)))
        + ($d | map(.plugin_id as $id | if $was | has($id) then .enabled = $was[$id] end))
      | if all(.[]; [has("plugin_id", "name", "version", "manifest_path", "plugin_root", "enabled")] | all)
        then . else error("an entry lacks a field herdr requires") end
    ' <<<"$current")

    [ "$new" = "$current" ] && exit 0
    mkdir -p "$(dirname "$registry")"
    printf '%s\n' "$new" > "$registry.tmp"
    mv "$registry.tmp" "$registry"
  '';
}
