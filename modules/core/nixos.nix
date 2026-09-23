{ inputs, lib, ... }:

{
  environment.sessionVariables = {
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";
  };

  # null removes the alias entirely; "" would still shadow the binary.
  environment.shellAliases.ls = lib.mkForce null;

  security.sudo.extraConfig = ''
    Defaults env_keep += "TERM COLORTERM TERMINFO"
  '';

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # nix-gaming ships prebuilt proton-osu/umu; without this they build from source.
      # `extra-` so these append to cache.nixos.org rather than replacing it.
      extra-substituters = [ "https://nix-gaming.cachix.org" ];
      extra-trusted-public-keys = [
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      ];
    };

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };
}
