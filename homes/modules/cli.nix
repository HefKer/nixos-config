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


  programs.fish.enable = false;
  programs.starship.enable = false;
  programs.atuin.enable = false;
  programs.bat.enable = false;
}
