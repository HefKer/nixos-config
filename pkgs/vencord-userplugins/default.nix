{
  lib,
  vencord,
  plugins,
}:
vencord.overrideAttrs (old: {
  pname = "vencord-with-userplugins";
  # Each plugin's own tsconfig points at a dev checkout; inside the tree Vencord's root one applies.
  postPatch =
    (old.postPatch or "")
    + lib.concatStrings (
      lib.mapAttrsToList (name: src: ''
        mkdir -p src/userplugins
        cp -r ${src} src/userplugins/${name}
        chmod -R u+w src/userplugins/${name}
        rm -f src/userplugins/${name}/tsconfig.json
      '') plugins
    );
})
