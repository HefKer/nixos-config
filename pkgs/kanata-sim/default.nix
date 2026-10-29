{ kanata }:
# kanata's key-event simulator, built from the same source as the running kanata so both agree.
kanata.overrideAttrs {
  pname = "kanata-sim";
  cargoBuildFlags = [
    "-p"
    "kanata-sim"
  ];
  doCheck = false;
  doInstallCheck = false;
  postInstall = "";
  meta = kanata.meta // {
    description = "Simulated input for kanata";
    mainProgram = "kanata_simulated_input";
  };
}
