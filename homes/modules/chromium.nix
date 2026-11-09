{ pkgs, ... }:
{
  # Agent-only browser for Claude in Chrome (extension force-installed by modules/roles/workstation/chromium.nix; Claude Code writes the native host itself).
  programs.chromium = {
    enable = true;
    package = pkgs.chromium;
    extensions = [
      { id = "ddkjiahejlhfcafbddmgiahcphecmpfh"; } # uBlock Origin Lite (Chromium dropped MV2, so full uBO no longer runs)
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
    ];
  };
}
