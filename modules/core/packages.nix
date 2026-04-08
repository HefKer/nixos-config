{ inputs, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    ripgrep
    fd
  ];

  programs = {
    vim.enable = true;
    git.enable = true;
  };
}
