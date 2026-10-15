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

      # Prebuilt nix-gaming (proton-osu/umu) and llm-agents tools; `extra-` appends to cache.nixos.org.
      extra-substituters = [
        "https://nix-gaming.cachix.org"
        "https://cache.numtide.com"
      ];
      extra-trusted-public-keys = [
        "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
        "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      ];
    };

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };
}
