{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # cargo-setup-hook sets AWS_LC_SYS_USE_SYSTEM=1 but tectonic lacks aws-lc in buildInputs, so its build panics; drop once nixpkgs fixes it
  nixpkgs.overlays = [
    (final: prev: {
      tectonic-unwrapped = prev.tectonic-unwrapped.overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ final.aws-lc ];
      });
    })
  ];

  environment.systemPackages = with pkgs; [
    ripgrep
    fd
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
