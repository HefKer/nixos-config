{ fetchFromGitHub, rustPlatform }:
rustPlatform.buildRustPackage {
  pname = "soloist-mpris";
  version = "0.2.2";
  src = fetchFromGitHub {
    owner = "TobiasVeiga00";
    repo = "soloist-mpris";
    rev = "664b5984a642fc8bf3e9a0dfa7f341089f6d3708";
    hash = "sha256-VytHdJL5IqZ2DWiPo7A3BTDaDIyeWFlUZ20H/Fs5354=";
  };
  cargoHash = "sha256-UOJHwsSepwPgoZSbgL028B2i1lDOQGx1ZXIH1rCucfY=";
  meta.mainProgram = "soloist-mpris";
}
