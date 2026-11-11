{ config, ... }:
{
  sops.secrets = {
    school-user = { };
    school-pw = { };
  };
  # NetworkManager substitutes $HCC_* in the profile below from this env file; root-owned, as ensure-profiles runs as root.
  sops.templates."hcc-wifi.env".content = ''
    HCC_IDENTITY=${config.sops.placeholder.school-user}
    HCC_PASSWORD=${config.sops.placeholder.school-pw}
  '';

  networking.networkmanager = {
    ensureProfiles = {
      environmentFiles = [ config.sops.templates."hcc-wifi.env".path ];
      profiles = {
        "HCCprivate" = {
          connection = {
            id = "HCCprivate";
            type = "wifi";
            autoconnect = "true";
          };
          wifi = {
            mode = "infrastructure";
            ssid = "HCCprivate";
          };
          wifi-security = {
            key-mgmt = "wpa-eap";
            auth-alg = "open";
          };
          "802-1x" = {
            eap = "peap";
            identity = "$HCC_IDENTITY";
            ca-cert = "/etc/ssl/certs/ca-certificates.crt";
            domain-suffix-match = "hccs.edu";
            phase2-auth = "mschapv2";
            phase2-subject-match = "";
            password = "$HCC_PASSWORD";
          };
          ipv4.method = "auto";
          ipv6 = {
            addr-gen-mode = "stable-privacy";
            method = "auto";
          };
        };
      };
    };
  };
}
