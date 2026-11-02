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
    unrar
    # File conversions
    imagemagick
    pandoc
    ffmpeg
    poppler-utils # pdftotext, pdfinfo, pdftoppm, ...
    # Editing secrets
    sops
    age
    ssh-to-age
  ];

  programs = {
    vim.enable = true;
    git = {
      enable = true;
      lfs.enable = true;
    };
  };
}
