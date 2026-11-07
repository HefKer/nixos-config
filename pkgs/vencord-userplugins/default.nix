{
  lib,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_11,
  vencord,
  plugins,
}:
vencord.overrideAttrs (
  finalAttrs: old: {
    pname = "vencord-with-userplugins";
    # nixpkgs' release lags Vencord's, and an outdated one's patches can break Discord's newest client to a blank window.
    version = "1.15.16";
    src = fetchFromGitHub {
      owner = "Vendicated";
      repo = "Vencord";
      tag = "v${finalAttrs.version}";
      hash = "sha256-aUJubLJpyLAZWiOezqFxPY6oVPgWVPQpajFqrJvrO9U=";
    };
    # nixpkgs' lockfile patch is for 1.15.13; newer releases pin @types/react through a pnpm catalog instead.
    patches = [ ];
    # Each plugin's own tsconfig points at a dev checkout; inside the tree Vencord's root one applies.
    postPatch = lib.concatStrings (
      lib.mapAttrsToList (name: src: ''
        mkdir -p src/userplugins
        cp -r ${src} src/userplugins/${name}
        chmod -R u+w src/userplugins/${name}
        rm -f src/userplugins/${name}/tsconfig.json
      '') plugins
    );
    pnpmDeps = fetchPnpmDeps {
      inherit (finalAttrs)
        pname
        version
        src
        patches
        ;
      pnpm = pnpm_11;
      fetcherVersion = 4;
      hash = "sha256-HS8uZNepvDefjrsG3buVLFCVv7sHvazcwdpcT3EQ/78=";
    };
  }
)
