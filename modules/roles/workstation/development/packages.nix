{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.custom.roles.workstation.development.packages;
in
{
  options.custom.roles.workstation.development.packages = with lib; {
    enable = mkEnableOption "Enable development packages";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # -- CLI tools ---
      gh
      gh-dash
      direnv
      yt-dlp #mc
      deno #mc
      tmux

      # --- File & Text Search/Manipulation CLI Tools ---
      jq

      # --- Development Tools ---
      # GUI
      zed-editor

      # Compilers
      gcc
      gdb

      # AI
      opencode
      gemini-cli
      github-copilot-cli
      claude-code

      # Rust
      rustup

      # Python
      python313
      python314
      pyright
      ruff
      python313Packages.debugpy
      uv

      # Lua
      lua55Packages.luarocks
      stylua
      lua-language-server

      # Nix
      nil
      nixfmt
      statix

      # Other Langs/Tools
      yaml-language-server
      markdownlint-cli2
      vscode-json-languageserver
      vscode-langservers-extracted

      # Shell Scripting
      bash-language-server
      shellcheck
      shfmt

      # Web Dev
      nodejs
      pnpm
    ];

    programs = {
      niri.enable = true; # todo: move
      obs-studio.enable = true; # todo: move
    };
  };
}
