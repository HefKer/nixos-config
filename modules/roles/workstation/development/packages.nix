{
  config,
  pkgs,
  ...
}:

{
  config = {
    environment.systemPackages = with pkgs; [
      # --- File & Text Search/Manipulation CLI Tools ---
      jq

      # --- Development Tools ---
      # Compilers
      gcc
      gdb

      # AI
      opencode
      gemini-cli
      github-copilot-cli

      # Rust
      rustup

      # Python
      python313
      pyright
      ruff
      python313Packages.debugpy

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
    ];

    programs = {
      niri.enable = true;
      obs-studio.enable = true;
    };
  };
}
