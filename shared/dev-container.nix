{
  lib,
  pkgs,
  config,
  machines,
  ...
}:
{
  options.devContainer = {
    enable = lib.mkEnableOption "Enable dev container";
    ssh.enable = lib.mkEnableOption "Enable SSH in dev container";
    python.enable = lib.mkEnableOption "Enable Python in dev container";
    conda.enable = lib.mkEnableOption "Enable Conda in dev container";
  };

  config = {
    # Host-level settings for containers
    boot.enableContainers = lib.mkIf config.devContainer.enable true;
    virtualisation.containers.enable = lib.mkIf config.devContainer.enable true;

    # NAT configuration for the container network
    networking.nat = lib.mkIf config.devContainer.enable {
      enable = true;
      internalInterfaces = [ "ve-dev-container" ];
      externalInterface = machines.melchior.interface;
      enableIPv6 = true;
    };

    # The container itself
    containers.dev-container = lib.mkIf config.devContainer.enable {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "192.168.100.10";
      localAddress = "192.168.100.11";
      config =
        {
          config,
          pkgs,
          lib,
          ...
        }:
        {
          # Container-specific services
          services.openssh.enable = lib.mkIf config.devContainer.ssh.enable true;
          services.openssh.settings.PasswordAuthentication = lib.mkIf config.devContainer.ssh.enable false;
          services.openssh.settings.PermitRootLogin = lib.mkIf config.devContainer.ssh.enable "yes";

          environment.systemPackages = lib.mkMerge [
            (lib.mkIf config.devContainer.python.enable [ pkgs.python3 ])
            (lib.mkIf config.devContainer.conda.enable [ pkgs.conda ])
          ];

          # Required for container networking
          services.resolved.enable = true;
          networking.useHostResolvConf = lib.mkForce false;
          system.stateVersion = "24.05";
        };
    };
  };
}
