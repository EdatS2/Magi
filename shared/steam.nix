# Steam (Sunshine + vuinputd) — host services + nspawn container
# Only enabled on melchior (NVIDIA GPU machines)

{
  config,
  pkgs,
  lib,
  ...
}:

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
      after = [ "multi-user.target" ];
      wants = [ "multi-user.target" ];
      requiredBy = [ "sunshine-container.service" ];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${vuinputd-pkgs.vuinputd}/bin/vuinputd --major 120 --minor 414795 --placement on-host";
        DeviceAllow = "char-* rwm";
      };
    };


    # ── NAT translation ──────────────────────────────────────────────

    # NAT configuration for the container network
    networking.nat = {
      enable = true;
      internalInterfaces = [ "ve-sunshine+" ];
      externalInterface = "kubernetes";
      internalIPs = [ "10.13.13.0/24" ];
      enableIPv6 = true;
    };

    # ── Sunshine nspawn container ──────────────────────────────────────────────

    containers.sunshine-container = {
      autoStart = true;
      privateNetwork = true;
      hostAddress = "10.13.13.6";
      localAddress = "10.13.13.50";
      config = import ./headless.nix;
      bindMounts = {
        "/dev/uinput" = {
          hostPath = "/dev/vuinput";
          isReadOnly = false;
        };
        "/dev/dri" = {
          hostPath = "/dev/dri";
          isReadOnly = false;
        };
        "/dev/nvidia-caps" = {
          hostPath = "/dev/nvidia-caps";
          isReadOnly = false;
        };
        "/dev/nvidia0" = {
          hostPath = "/dev/nvidia0";
          isReadOnly = false;
        };
        "/dev/nvidia-modeset" = {
          hostPath = "/dev/nvidia-modeset";
          isReadOnly = false;
        };
        "/dev/nvidiactl" = {
          hostPath = "/dev/nvidiactl";
          isReadOnly = false;
        };
        "/dev/nvidia-uvm" = {
          hostPath = "/dev/nvidia-uvm";
          isReadOnly = false;
        };
        "/dev/nvidia-uvm-tools" = {
          hostPath = "/dev/nvidia-uvm-tools";
          isReadOnly = false;
        };
        "/dev/input" = {
          hostPath = "/run/vuinputd/vuinput/dev-input";
          isReadOnly = false;
        };
      };
      allowedDevices = [
        {
          node = "/dev/vuinput";
          modifier = "rw";
        }
        {
          node = "/dev/dri/card1";
          modifier = "rw";
        }
        {
          node = "/dev/dri/renderD128";
          modifier = "rw";
        }
        {
          node = "/dev/dri/card2";
          modifier = "rw";
        }
        {
          node = "/dev/dri/renderD129";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia0";
          modifier = "rw";
        }
        {
          node = "/dev/nvidiactl";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia-modeset";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia-uvm";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia-uvm-tools";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia-caps/nvidia-cap1";
          modifier = "rw";
        }
        {
          node = "/dev/nvidia-caps/nvidia-cap2";
          modifier = "rw";
        }
      ];
    };
  };
}
