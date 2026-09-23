{
  config,
  lib,
  pkgs,
  inputs,
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
    # sadjow's flake tracks Anthropic's releases hourly; nixpkgs lags by days.
    nixpkgs.overlays = [ inputs.claude-code.overlays.default ];

    environment.systemPackages = with pkgs; [
      # -- CLI tools ---
      gh
      gh-dash
      yt-dlp # mc
      deno # mc
      herdr
      hunk

      # --- File & Text Search/Manipulation CLI Tools ---
      jq

      # --- Display / mirroring ---
      wl-mirror # mirror one Wayland output into a window
      wlr-randr # query/set output modes at runtime (resolution, position)

      # --- Development Tools ---
      # GUI
      zed-editor

      # Compilers
      gcc
      gdb

      # AI
      opencode
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
      luajitPackages.luarocks
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
      niri.enable = true;
      obs-studio.enable = true;

      # nix-direnv keeps dev shells rooted so GC doesn't collect them
      direnv = {
        enable = true;
        nix-direnv.enable = true;
        silent = true;
      };
    };
  };
}
