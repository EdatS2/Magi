#steam_server
{ lib, pkgs, machines, config, ... }:
let 
    cfg = config.steam_server.enable;
in
{
    options.steam_server = {
        enable = lib.mkEnableOption "Enable Steam server";
    };

    config = lib.mkIf cfg {
         # X and audio
    hardware.pulseaudio.enable = false;
    security.rtkit.enable = true;
    programs.uwsm = {
        enable = true;
        waylandCompositors = {
        hyprland = {
          prettyName = "Hyprland";
          comment = "Hyprland compositor managed by UWSM";
          binPath = "${pkgs.hyprland}/bin/Hyprland";
        };
       sway = {
          prettyName = "Sway";
          comment = "Sway compositor managed by UWSM";
          binPath = "${pkgs.sway}/bin/sway";
        };
       } ;
    };
    xdg.portal.enable = true;
    xdg.portal.wlr.enable = true;
    programs.hyprland.enable = true;

    programs.sway = {
        enable = true;
        extraSessionCommands = ''
            export DESKTOP_SESSION="sway"
            export XDG_CURRENT_DESKTOP="sway"
            export XDG_SESSION_DESKTOP="sway"
            export XDG_SESSION_TYPE="wayland"
            export WLR_BACKENDS="headless,libinput"
            # OpenGL Variables
            export GBM_BACKEND=nvidia-drm
            export __GL_GSYNC_ALLOWED=0
            export __GL_VRR_ALLOWED=0
            export __GLX_VENDOR_LIBRARY_NAME=nvidia
# Xwayland compatibility
            export XWAYLAND_NO_GLAMOR=1
        '';
        };
    
    # Sunshine user, service and config 
    users.users.sunshine = {
        isNormalUser  = true;
        home  = "/home/sunshine";
        description  = "Sunshine Server";
        extraGroups  = [ "wheel" "networkmanager" "input" "video" "sound"];
        openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPsp/GP+FOMXJmr34gO5055gqvlAF7Q/QK72XXBIa6O tadesalverda@outlook.com"
      ];
        hashedPassword =
        "$y$j9T$yqwYRrZy5iBJVX86iejJq.$.kautymt0ch6mTqgS95z19BqA9cUczPbd1rjM3PtRG7";
    };

    services.sunshine = {
        enable = true;
        autoStart = true;
        capSysAdmin = true;
        package = pkgs.sunshine.override{ cudaSupport = true;};
        settings = {
          sunshine_name = "nixos";
          capture = "wlr";
        };
        applications = {
          env = {
            PATH = "$(PATH):$(HOME)/.local/bin";
          };
          apps = [
            {
              name = "Steam";
              # prep-cmd = [
              #   {
              #     # do = ''${pkgs.bash}/bin/sh -c "${pkgs.sway}/bin/swaymsg output HEADLESS-1 enable;
              #     # ${pkgs.sway}/bin/swaymsg output HEADLESS-1 mode
              #     # ${builtins.getEnv "SUNSHINE_CLIENT_WIDTH"}x${"SUNSHINE_CLIENT_HEIGHT"}@${builtins.getEnv
              #     # "SUNSHINE_CLIENT_FPS"}Hz;
              #     # do = ''${pkgs.bash}/bin/sh -c "${pkgs.sway}/bin/swaymsg output HEADLESS-1 enable;
              #     # ${pkgs.sway}/bin/swaymsg output HEADLESS-1 mode
              #     # 1920x1080@60Hz;
              #     # ${pkgs.sway}/bin/swaymsg output HDMI-1 disable"'';
              #     # undo = "${pkgs.sway}/bin/swaymsg output HEADLESS-1 disable;
              #     # ${pkgs.sway}/bin/swaymsg output HDMI-1 enable";
              #   }
              # ];
              exclude-global-prep-cmd = "false";
              auto-detach = "true";
              detached = ["${pkgs.util-linux}/bin/setsid ${pkgs.steam}/bin/steam steam://open/bigpicture"];
              image-path = "steam.png";
            }
          ];
        }
        ;
    };

    
    # Avahi is used by Sunshine
    services.avahi.publish.userServices = true;

    # Required to simulate input
    boot.kernelModules = [ "uinput" ];

    # Maybe not necessary ? udev rules are ignored with ssh ?
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    '';

    # Force stop udisks2 (conflict with Gnome)
    services.udisks2.enable = lib.mkForce false;

    # Steam
    programs.steam.enable = true;

    # Enable OpenGL
    };
}
