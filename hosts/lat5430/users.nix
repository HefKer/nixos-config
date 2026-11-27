{
  # No password here, the repo being public: `sudo passwd guest` on the machine sets it once.
  users.users.guest = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" ];
  };
}
