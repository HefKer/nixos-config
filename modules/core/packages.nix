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
    # snacks.image in nvim: PDFs, LaTeX math, Mermaid diagrams
    ghostscript
    tectonic
    mermaid-cli
  ];

  programs = {
    vim.enable = true;
    git = {
      enable = true;
      lfs.enable = true;
    };
  };
}
