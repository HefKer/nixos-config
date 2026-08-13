{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  # moonlight-qt 6.1.0's Vulkan renderer uses AVVulkanDeviceContext fields
  # (queue_family_decode_index, nb_decode_queues) that ffmpeg 9.0 removed, so it
  # fails to compile against the channel's default ffmpeg. Build it against
  # ffmpeg 8 until upstream catches up. Remove once nixpkgs bumps moonlight-qt.
  nixpkgs.overlays = [
    (final: prev: { moonlight-qt = prev.moonlight-qt.override { ffmpeg = prev.ffmpeg_8; }; })
  ];

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
