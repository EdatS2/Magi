# Python nspawn container — limited to 4 cores
# Only enabled on melchior (NVIDIA GPU machines)

{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.pythonServer.enable;
in
{
  config = lib.mkIf cfg {
    # ── Python nspawn container ──────────────────────────────────────────────

    containers.python-container = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "10.13.13.6";
      localAddress = "10.13.13.51";
      config = import ./python.nix;
    };

    # Limit container to 4 CPU cores (400% of 1 core)
    systemd.services."container-python-container".serviceConfig.CPUQuotaPerSecSec = "400%";
  };
}
