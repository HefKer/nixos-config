{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  nixIndex = config.programs.nix-index.package;

  # HM's shell integrations write to programs.<shell>, unused here; fish's also and hooks an event fish 4 never emits: override the function.
  fishHandler = pkgs.writeTextDir "share/fish/vendor_conf.d/nix-index.fish" ''
    function fish_command_not_found
        ${lib.getExe pkgs.bash} -c 'source ${nixIndex}/etc/profile.d/command-not-found.sh; command_not_found_handle "$@"' _ $argv
    end
  '';
in
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  programs.nix-index = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
    # The wrapped binaries already point at the database, so nothing reads ~/.cache/nix-index.
    symlinkToCacheHome = false;
  };

  programs.nix-index-database.comma.enable = true;

  home.packages = [ fishHandler ];
}
