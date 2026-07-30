{ consts, ... }:
{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "hefker";
        email = "nelsonjulioaviles@gmail.com";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
    };
    ignores = [
      ".stglobalignore"
      "CLAUDE.md"
      ".claude/"
      "docs/"
      "CONTEXT.md"
      "/.scratch"
      "inspo/"
      ".stfolder/"
    ];
  };


  programs.fish.enable = false;
  programs.starship.enable = false;
  programs.atuin.enable = false;
  programs.bat.enable = false;
}
