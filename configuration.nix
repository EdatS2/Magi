{ modulesPath
, lib
, pkgs
, ...
}:
let
  kubeMasterIP = "10.13.13.2";
  kubeMasterHostname = "api.kube";
  kubeMasterAPIServerPort = 6443;
in
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;

  environment.systemPackages = map lib.lowPrio [
    pkgs.curl
    pkgs.gitMinimal
    pkgs.neovim
  ];
  networking = {
    extraHosts = "${kubeMasterIP} ${kubeMasterHostname}";
    hostName = "KubeMaster";
    dhcpcd.enable = true;
    # interfaces.ens18.ipv4.addresses = [{ address = "192.168.88.30"; prefixLength = 28; }];
    vlans = {
      kubernetes = {
        id = 100;
        interface = "ens18";
      };
    };
    # interfaces.kubernetes.ipv4.addresses = [{
    #     address = "10.13.13.2";
    #     prefixLength = 24;
    # }];
    defaultGateway = "10.13.13.1";
  };
  services.kubernetes = {
    roles = [ "master" "node" ];
    masterAddress = kubeMasterHostname;
    apiserverAddress = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
    easyCerts = true;
    apiserver = {
      securePort = kubeMasterAPIServerPort;
      advertiseAddress = kubeMasterIP;
    };
    addons.dns.enable = true;
  };
  users.users.admin = {
    isNormalUser = true;
    hashedPassword = "$6$JJs5A4jYfGS9Wec4$Y7IBfFKQ/xBSW4c/oxP6cXivhs0AwMU2UznO0SPdGaZM/i.LcpydKg38hbJ6lf4aXZ7D9X1Q.rNpM3dGaBTur.";
    extraGroups = ["wheel"];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPsp/GP+FOMXJmr34gO5055gqvlAF7Q/QK72XXBIa6O tadesalverda@outlook.com"
  ];
  # we want immutable users
  # because this makes the system fully reproducible, nothing should be configured on the command line
  users.mutableUsers = false;

  system.stateVersion = "24.05";
}
