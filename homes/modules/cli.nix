{ consts, ... }:
{
  programs.git = {
    enable = true;
    userName = "hefker";
    userEmail = "nelsonjulioaviles@gmail.com";
  };

  programs.fish.enable = true;
  programs.starship.enable = true;
  programs.atuin.enable = true;
  programs.bat.enable = true;
}
