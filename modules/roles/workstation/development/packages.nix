{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.custom.roles.workstation.development;
  llm-agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # -- CLI tools ---
      gh
      gh-dash
      yt-dlp # mc
      deno # mc
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

      # AI (llm-agents.nix updates daily; nixpkgs lags by days to weeks)
      llm-agents.claude-code
      llm-agents.opencode
      llm-agents.herdr
      llm-agents.collie
      (callPackage ../../../../pkgs/skillshare.nix { })

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
