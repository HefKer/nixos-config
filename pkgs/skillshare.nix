{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "skillshare";
  version = "0.21.12";

  src = fetchFromGitHub {
    owner = "runkids";
    repo = "skillshare";
    rev = "v${version}";
    hash = "sha256-CWwxrt8Ok0UL0giHDkVx47TCcJKQQx8GiDtiPVs4r8Y=";
  };

  vendorHash = "sha256-9yIhL0lKTTCGuF2ClHMS7viD9g7za8EMI2Qm6zq/oVQ=";
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
