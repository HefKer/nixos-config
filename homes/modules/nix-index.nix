{
  config,
  inputs,
  pkgs,
  ...
}:
let
  inherit (config.programs.nix-index) package;

  # HM's fish integration writes to programs.fish, unused here, and hooks an event fish 4 never emits: override the function.
  fishHandler = pkgs.writeTextDir "share/fish/vendor_conf.d/nix-index.fish" ''
    function fish_command_not_found
        ${pkgs.bash}/bin/bash -c 'source ${package}/etc/profile.d/command-not-found.sh; command_not_found_handle "$@"' _ $argv
    end
  '';
in
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  programs.nix-index = {
    enable = true;
    enableFishIntegration = false;
    # The wrapped binaries already point at the database, so nothing reads ~/.cache/nix-index.
    symlinkToCacheHome = false;
  };

  # `, <tool>` runs any nixpkgs binary without installing it.
  programs.nix-index-database.comma.enable = true;

  home.packages = [ fishHandler ];
}
