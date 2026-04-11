{ inputs, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    ripgrep
    fd
    syncthing
  ];

  programs = {
    vim.enable = true;
    git.enable = true;
  };
}
