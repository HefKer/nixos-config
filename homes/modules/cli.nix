{ consts, ... }:
{
  programs.git = {
    enable = true;
    settings.user = {
      name = "hefker";
      email = "nelsonjulioaviles@gmail.com";
    };
    ignores = [
      ".stglobalignore"
      "CLAUDE.md"
      ".claude/"
    ];
  };

  programs.fish.enable = true;
  programs.starship.enable = true;
  programs.atuin.enable = true;
  programs.bat.enable = true;
}
