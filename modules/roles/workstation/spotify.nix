{
  config,
  lib,
  consts,
  ...
}:
{
  config = lib.mkIf config.custom.roles.workstation.enable {
    sops.secrets.soloist-api-key.sopsFile = ../../../secrets/shared.yaml;
    # Soloist only takes its key on the command line, so the user service reads it from an env file.
    sops.templates."soloist.env" = {
      owner = consts.username;
      content = "SOLOIST_API_KEY=${config.sops.placeholder.soloist-api-key}\n";
    };
  };
}
