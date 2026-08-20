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
    czkawka
    p7zip
    moonlight-qt
    wl-clipboard
    # File conversions
    imagemagick
    pandoc
    ffmpeg
  ];

  programs = {
    vim.enable = true;
    git.enable = true;
  };
}
