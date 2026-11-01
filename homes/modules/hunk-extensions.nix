{ pkgs, ... }:
let
  markAsReviewed = pkgs.fetchFromGitHub {
    owner = "evantravers";
    repo = "hunk-mark-as-reviewed";
    rev = "8ca0c4654b629724c29febaeed34f466c6a9bb7c";
    hash = "sha256-x07xHxA9U3ZGEGtBfJkEpodTq2rOVjwwxFH3NCy8CUM=";
  };
in
{
  # Symlink installed/ whole, never `recursive = true`: file links lose hunk's react rewrite, and its scanner skips a symlinked extension folder, so each extension is a real folder inside.
  home.file.".config/hunk/extensions/installed".source = pkgs.runCommandLocal "hunk-extensions" { } ''
    mkdir $out
    cp -r ${markAsReviewed} $out/hunk-mark-as-reviewed
  '';
}
