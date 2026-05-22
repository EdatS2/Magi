# Headless Steam + Sunshine streaming server
{ lib, pkgs, config, ... }:
let
  cfg = config.steam_server;
  
  labwcConfigDir = pkgs.runCommand "labwc-config" { } ''
    mkdir -p $out
    ln -s ${lib.getExe labwcAutostart} $out/autostart
  '';
    # Signals systemd that labwc is ready, which unblocks sunshine.service.
  # This is the only entry in labwc's autostart for this minimal setup.
  # Add wallpaper, polkit agents, or application launchers here as needed.
  labwcAutostart = pkgs.writeShellApplication {
    name           = "labwc-autostart";
    runtimeInputs  = [ pkgs.systemd ];
    text           = ''systemd-notify READY=1'';
  };
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
      systemd.user.services.headless-labwc = {
    description = "Headless Wayland compositor (labwc)";
    wantedBy    = [ "default.target" ];
    after       = [ "basic.target" ];
    requires    = [ "dbus.socket" ];
    wants       = [ "dbus.socket" ];
    serviceConfig = {
      Type           = "notify";
      NotifyAccess   = "all";
      ExecStart      = "${pkgs.labwc}/bin/labwc -C ${labwcConfigDir}";
      KillMode       = "mixed";
      TimeoutStopSec = 15;
    };
    environment = {
      WLR_BACKENDS                     = "headless,libinput";
      WLR_LIBINPUT_NO_DEVICES          = "1";
      LIBSEAT_BACKEND                  = "noop";
      LABWC_UPDATE_ACTIVATION_ENV      = "1";
      WLR_SCENE_DISABLE_DIRECT_SCANOUT = "0";
      WLR_NO_HARDWARE_CURSORS          = "1";
    };
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
