# Plain data, also read by checks/: a host builds only the folder rows whose peers include it.
let
  workstations = [
    "desktop"
    "lenovo"
  ];
  staggered = days: {
    type = "staggered";
    maxAgeDays = days;
  };
  trashcan = days: {
    type = "trashcan";
    maxAgeDays = days;
  };
in
{
  # Device IDs are public keys; a peer named after a host is that host. Read one with `nix run nixpkgs#syncthing -- device-id`.
  peers = {
    desktop = {
      id = "GTGPGV7-IG4TW7R-SNXTIVC-ZWFKAAE-WDEMBKF-CFXT7NX-HT7ITHX-VAHQSA5";
      address = "100.75.119.89";
    };
    lenovo = {
      id = "B6QRXT2-62YMLWX-TVMBC6L-ZTJIDRT-MLI6GFD-NK6PXWR-WLNYBKK-WUNWHQI";
      address = "100.90.76.120";
    };
    phone.id = "32NQBTH-U4ZQR7J-EA5YTDY-Y3LJ5QH-S3KPBG6-ZRE74KW-Y2DOA6W-JZNNZA4";
  };

  # Folder IDs must match on every peer; changing one orphans the folder.
  folders = {
    Projects = {
      id = "qcgdf-fxdnt";
      path = "01-Projects";
      peers = workstations;
      versioning = staggered 90;
    };
    Areas = {
      id = "vsjrm-wazna";
      path = "02-Areas";
      peers = workstations;
      versioning = staggered 90;
    };
    Resources = {
      id = "el7ue-cpyvj";
      path = "03-Resources";
      peers = workstations;
      versioning = staggered 90;
    };
    Archive = {
      id = "em9ys-geh2a";
      path = "04-Archive";
      peers = workstations;
      versioning = trashcan 90;
      exclude = [ "(?d).smart-env" ];
    };
    polaris = {
      id = "yfobb-xze03";
      path = "polaris";
      peers = workstations ++ [ "phone" ];
      versioning = staggered 90;
      ignorePerms = true;
      exclude = [ "(?d).obsidian/workspace*" ];
    };
    dots = {
      id = "tt7lu-osc6p";
      path = "dots";
      peers = workstations;
      versioning = trashcan 14;
      exclude = [
        "*.bak*"
        "// DMS writes this host's monitor layout here"
        "niri/.config/niri/dms/outputs.kdl"
        "(?d)niri/.config/niri/config.kdl.backup*"
        "(?d)DankMaterialShell/.config/DankMaterialShell/.firstlaunch"
        "(?d)DankMaterialShell/.config/DankMaterialShell/.changelog-*"
        "// DMS plugin clones: not deletable, re-cloning isn't free"
        "DankMaterialShell/.config/DankMaterialShell/plugins"
        "// fish universal variables hold machine-local paths"
        "fish/.config/fish/fish_variables"
        "// Helium profile: only safe files and extensions; close the browser on both ends while syncing"
        "helium/.config/net.imput.helium/**/LOCK"
        "helium/.config/net.imput.helium/**/LOG"
        "helium/.config/net.imput.helium/**/LOG.old"
        "!helium/.config/net.imput.helium/Default/Bookmarks"
        "!helium/.config/net.imput.helium/Default/Preferences"
        "!helium/.config/net.imput.helium/Default/Secure Preferences"
        "!helium/.config/net.imput.helium/Default/custom_dictionary.txt"
        "!helium/.config/net.imput.helium/Default/Extensions/**"
        "!helium/.config/net.imput.helium/Default/Extensions"
        "!helium/.config/net.imput.helium/Default/Local Extension Settings/**"
        "!helium/.config/net.imput.helium/Default/Local Extension Settings"
        "!helium/.config/net.imput.helium/Local State"
        "!helium/.config/net.imput.helium/Default"
        "!helium/.config/net.imput.helium"
        "helium/.config/net.imput.helium/**"
      ];
    };
    nixos = {
      id = "qx9dv-ea6wq";
      path = "nixos";
      peers = workstations;
      versioning = trashcan 14;
    };
    dev = {
      id = "zgaqy-fpma6";
      path = "dev";
      peers = workstations;
      versioning = trashcan 14;
    };
    Pictures = {
      id = "p9fxe-rffiz";
      path = "Pictures";
      peers = workstations;
      versioning = trashcan 90;
    };
    "Phone Images" = {
      id = "zoktz-z7nsz";
      path = "Phone";
      peers = [
        "desktop"
        "phone"
      ];
      versioning = trashcan 90;
      ignorePerms = true;
    };
    Downloads = {
      id = "yftau-peu5g";
      path = "Downloads";
      peers = workstations;
    };

    # App-state folders: only the named paths sync.
    ".claude" = {
      id = "awqza-4tmhz";
      path = ".claude";
      peers = workstations;
      syncOnly = [
        "projects"
        "sessions"
        "file-history"
        "plugins/installed_plugins.json"
        "plugins/known_marketplaces.json"
        "skills"
        "settings.json"
        "CLAUDE.md"
        "commands"
        "hooks"
        "keybindings.json"
      ];
    };
    ".local qutebrowser" = {
      id = "jmvq4-pxakp";
      path = ".local/share/qutebrowser";
      peers = workstations;
      syncOnly = [ "sessions" ];
    };
  };
}
