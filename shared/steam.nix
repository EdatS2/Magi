# Steam (Sunshine + vuinputd) — host services + nspawn container
# Only enabled on melchior (NVIDIA GPU machines)

{ config, pkgs, lib, machines, ... }:

let
  cfg = config.steam.enable;
  vuinputd-pkgs = import ./vuinput.nix { inherit pkgs; };
in
{
  options.steam = {
    enable = lib.mkEnableOption "Enable Steam (Sunshine + vuinputd) setup";
  };

  config = lib.mkIf cfg {

    # ── vuinputd: udev rules ────────────────────────────────────────────────────

    # udev rules from the derivation are at $out/etc/udev/rules.d/ —
    # NixOS picks these up automatically via services.udev.packages
    services.udev.packages = [ vuinputd-pkgs.vuinputd ];

    # ── vuinputd: systemd service ──────────────────────────────────────────────

    systemd.services.vuinputd = {
      description = "vuinputd - Virtual uinput daemon";
      after       = [ "multi-user.target" ];
      wants       = [ "multi-user.target" ];
      requiredBy  = [ "sunshine-container.service" ];
      serviceConfig = {
        Type            = "notify";
        Restart         = "on-failure";
        RestartSec      = 5;
        ExecStart       = "${vuinputd-pkgs.vuinputd}/bin/vuinputd --major 120 --minor 414795 --placement on-host";
        DeviceAllow     = "char-cuse rwm";
        ReadWritePaths  = "/run/vuinputd";
      };
    };

    # ── Sunshine nspawn container ──────────────────────────────────────────────

    containers.sunshine-container = {
      autoStart = true;
      config    = import ./headless.nix;
      bindMounts = {
        "/dev/uinput" = {
          hostPath   = "/dev/vuinput";
          isReadOnly = false;
        };
        "/dev/dri" = {
          hostPath   = "/dev/dri";
          isReadOnly = false;
        };
        "/dev/input" = {
          hostPath   = "/run/vuinputd/vuinput/dev-input";
          isReadOnly = false;
        };
      };
      allowedDevices = [
        {
          node     = "/dev/vuinput";
          modifier = "rw";
        }
        {
          node     = "/dev/dri/card0";
          modifier = "rw";
        }
        {
          node     = "/dev/dri/renderD128";
          modifier = "rw";
        }
      ];
    };
  };
}
