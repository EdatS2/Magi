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
    enable = if machines.${config.system.name}.node then true else false;
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
        interface = "kubernetes";
        virtualIps = [ { addr = machines.kubeMaster.ip; } ];
        priority = if machines.${config.system.name}.master then 101 else 100;
        virtualRouterId = 51;
        trackScripts = [ "check_haproxy" ];
      };
    };
  };
}
