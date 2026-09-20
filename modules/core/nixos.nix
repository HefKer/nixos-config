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
    };

    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };
}
