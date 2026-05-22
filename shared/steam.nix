# Headless Steam + Sunshine streaming server
{ lib, pkgs, config, ... }:
let
  cfg = config.steam_server;
in
{
  options.steam_server = {
    enable = lib.mkEnableOption "Enable Steam headless streaming server";
  };

  config = lib.mkIf cfg.enable {
    # --- Audio (Pipewire/WirePlumber) ---
    hardware.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire.enable = true;
    services.pipewire.alsa.enable = true;
    services.pipewire.alsa.support32Bit = true;
    services.pipewire.wireplumber.enable = true;

    # --- Headless Wayland compositor (labwc) ---
    # Runs in the sunshine user's default session
    systemd.user.services.labwc = {
      enable = true;
      serviceConfig = {
        Environment = [
          "WLR_BACKENDS=headless,libinput"
          "WLR_LOG=verbose"
          "GBM_BACKEND=nvidia-drm"
          "__GL_GSYNC_ALLOWED=0"
          "__GL_VRR_ALLOWED=0"
          "__GLX_VENDOR_LIBRARY_NAME=nvidia"
        ];
        ExecStart = "${pkgs.labwc}/bin/labwc";
        Restart = "always";
        RestartSec = 3;
      };
      wantedBy = [ "default.target" ];
    };

    # --- Sunshine user ---
    users.users.sunshine = {
      isNormalUser = true;
      home = "/home/sunshine";
      description = "Sunshine Server";
      extraGroups = [ "wheel" "networkmanager" "input" "video" "sound" ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPsp/GP+FOMXJmr34gO5055gqvlAF7Q/QK72XXBIa6O tadesalverda@outlook.com"
      ];
      hashedPassword =
        "$y$j9T$yqwYRrZy5iBJVX86iejJq.$.kautymt0ch6mTqgS95z19BqA9cUczPbd1rjM3PtRG7";
    };

    # Enable linger for sunshine user (user services start at boot)
    systemd.services.enable-linger-sunshine = {
      enable = true;
      description = "Enable linger for sunshine user";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/loginctl enable-linger sunshine";
      };
      wantedBy = [ "multi-user.target" ];
    };

    # --- Sunshine service ---
    services.sunshine = {
      enable = true;
      autoStart = true;
      openFirewall = true;
      capSysAdmin = true;
      package = pkgs.sunshine.override { cudaSupport = true; };
      settings = {
        sunshine_name = "melchior";
        capture = "wlr";
        output_name = "3";
        video_codec = "h264";
        audio_codec = "opus";
      };
      applications = {
        env = {
          PATH = "$PATH:/home/sunshine/.local/bin";
        };
        apps = [
          {
            name = "Steam";
            exclude-global-prep-cmd = "false";
            auto-detach = "true";
            detached = [
              "${pkgs.util-linux}/bin/setsid ${pkgs.steam}/bin/steam steam://open/bigpicture"
            ];
            image-path = "steam.png";
          }
        ];
      };
    };

    # Firewall for Sunshine (manual in case openFirewall doesn't cover all)
    networking.firewall.allowedTCPPorts = [ 47984 47989 47990 48010 ];
    networking.firewall.allowedUDPPorts = [ 47998 47999 48000 48002 48010 ];

    # Avahi for discovery
    services.avahi.publish.userServices = true;

    # Input simulation
    boot.kernelModules = [ "uinput" ];
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    '';

    # Force stop udisks2
    services.udisks2.enable = lib.mkForce false;

    # Steam
    programs.steam.enable = true;
  };
}
