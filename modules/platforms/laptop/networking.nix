{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf (config.custom.platform == "laptop") {
    networking.networkmanager = {
      ensureProfiles = {
        # Not in the repo — create it by hand with $HCC_IDENTITY and $HCC_PASSWORD.
        environmentFiles = [ "/etc/nixos/secrets/hcc-wifi.env" ];
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
  };
}
