{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "skillshare";
  version = "0.26.4";

  src = fetchFromGitHub {
    owner = "runkids";
    repo = "skillshare";
    rev = "v${version}";
    hash = "sha256-MjeVg8IWQBn7hqO+X3KnhOdtMqWtm3GtEWPiMRUIuUY=";
  };

  vendorHash = "sha256-vZxkLUP6E+tyat87VBpW3kr+JtXJizTHmEkiJDoZzbg=";
  subPackages = [ "cmd/skillshare" ];
  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];
  # tests shell out to git / hit the network, which the build sandbox blocks
  doCheck = false;

  meta = {
    description = "Sync skills, agents and rules across AI CLI tools";
    homepage = "https://github.com/runkids/skillshare";
    license = lib.licenses.mit;
    mainProgram = "skillshare";
  };
}
