{
  modulesPath,
  lib,
  pkgs,
  config,
  machines,
  ...
}:
with builtins;
with pkgs.lib;
{
  services.keepalived = {
    enable = machines.${config.system.name}.master;
    package = pkgs.keepalived;
    vrrpScripts = {
      "check_haproxy" = {
        script = "/bin/sh -c 'killall -0 haproxy || true'";
        interval = 2;
      };
    };
    vrrpInstances = {
      "1" = {
        state = if machines.${config.system.name}.master then "MASTER" else "BACKUP";
        interface = machines.${config.system.name}.interface;
        virtualIps = [ { addr = machines.kubeMaster.ip; } ];
        priority = if machines.${config.system.name}.master then 101 else 100;
        virtualRouterId = 51;
        trackScripts = [ "check_haproxy" ];
      };
    };
  };
}
