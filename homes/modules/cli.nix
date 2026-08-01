{ consts, ... }:
{
  programs = {

    git = {
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
        # Syncthing
        ".stglobalignore"
        ".stignore"
        ".stfolder/"

        # Reference
        "reference/"

        # Agent files
        "CLAUDE.md"
        "CONTEXT.md"
        "/.claude"
        "/docs"
        "/.scratch"
      ];
    };

  };
}
