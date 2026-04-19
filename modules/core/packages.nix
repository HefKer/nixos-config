{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    ripgrep
    fd
    syncthing
    wget # nix search wget to list installed pkgs
    tree-sitter
    lsof
    p7zip
    moonlight-qt
  ];

  programs = {
    vim.enable = true;
    git.enable = true;
  };
}
