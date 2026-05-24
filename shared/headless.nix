# Note, I gave claude my personal setup and asked it to cleanup and document it,
# but I did not manage to test it out and clean it up myself. So use it with caution.
# Nevertheless, it should give you some inspiration how to do things.
#
# Minimal NixOS container — headless Sunshine with vuinputd
#
# Sunshine is downloaded automatically by Nix from the nixpkgs binary cache
# (cache.nixos.org) when you run nixos-rebuild switch. No manual installation
# or compilation is required. Nix resolves pkgs.sunshine to a store path such
# as /nix/store/...-sunshine-<version>/bin/sunshine.
#
# See README-NIXOS-CONTAINER.md for host setup and first-run instructions.

{ config, pkgs, lib, ... }:

let
  userName = "gamer";
  userId   = 1000;

  # pkgs.writeShellApplication wraps the script with a strict bash environment
  # (set -euo pipefail), runs shellcheck at build time, and adds the declared
  # runtimeInputs to PATH inside the script — so binaries like stat, groupmod,
  # and systemd-notify can be used without store paths.
  # lib.getExe returns the full /nix/store/... path to the script binary.

  # Signals systemd that labwc is ready, which unblocks sunshine.service.
  # This is the only entry in labwc's autostart for this minimal setup.
  # Add wallpaper, polkit agents, or application launchers here as needed.
  labwcAutostart = pkgs.writeShellApplication {
    name           = "labwc-autostart";
    runtimeInputs  = [ pkgs.systemd ];
    text           = ''systemd-notify READY=1'';
  };

  # Creates /run/udev stubs required by libinput and libudev.
  fakeUdev = pkgs.writeShellApplication {
    name           = "fake-udev";
    runtimeInputs  = [ pkgs.coreutils ];
    text           = ''
      mkdir -p /run/udev/data
      touch /run/udev/control
      echo "/run/udev/control is set up"
    '';
  };

  # Waits until /dev/uinput appears (bind-mounted from the host by nspawn).
  # Times out via systemd's TimeoutStartSec rather than an inline counter.
  waitForUinput = pkgs.writeShellApplication {
    name           = "wait-for-uinput";
    runtimeInputs  = [ pkgs.coreutils ];
    text           = ''
      while [ ! -e /dev/uinput ]; do
        sleep 0.5
      done
    '';
  };

  # Reads the GIDs of the bind-mounted /dev/dri devices and adjusts the render
  # and video group GIDs to match. Required because nspawn passes through the
  # host's device nodes; group GIDs must match the host for the gamer user to
  # access the GPU.
  setupDriGroups = pkgs.writeShellApplication {
    name           = "setup-dri-groups";
    runtimeInputs  = [ pkgs.coreutils pkgs.shadow ];
    text           = ''
      adjust_gid() {
        local group=$1
        local device=$2
        if [ ! -e "$device" ]; then
          echo "$device does not exist, skipping $group"
          return
        fi
        local gid
        gid=$(stat -c "%g" "$device")
        echo "$device has GID $gid — setting group $group"
        groupmod -g "$gid" "$group" || \
          echo "Warning: could not set GID $gid for group $group (may already be correct)"
      }

      adjust_gid render /dev/dri/renderD128
      adjust_gid video  /dev/dri/card0
    '';
  };

  labwcConfigDir = pkgs.runCommand "labwc-config" { } ''
    mkdir -p $out
    ln -s ${lib.getExe labwcAutostart} $out/autostart
  '';

in
{
  system.stateVersion    = "25.05";
  boot.isContainer       = true;
  boot.isNspawnContainer = true;

  # ── User ──────────────────────────────────────────────────────────────────────

  users.users.${userName} = {
    isNormalUser = true;
    uid          = userId;
    # linger = true starts the user@1000 systemd session at boot without a
    # login. This is what makes labwc, pipewire, and sunshine start
    # automatically. Requires NixOS 24.05+. On older releases use:
    #   systemd.tmpfiles.rules = [ "f /var/lib/systemd/linger/${userName} 0644 root root -" ];
    linger      = true;
    extraGroups = [ "video" "render" "input" ];
  };

  # Declare the groups so the gamer user can be added to them at activation
  # time. The actual GIDs are adjusted dynamically at boot by setup-dri-groups,
  # because they must match whatever GIDs the host assigns to /dev/dri devices
  # passed through via bind mount.
  users.groups.render = {};
  users.groups.video  = {};

  # ── Networking ────────────────────────────────────────────────────────────────

  # nspawn creates a veth pair via host0. Network config is inherited
  # from the NixOS container framework — no explicit networking config needed.

  # Moonlight requires these ports to be open.
  networking.firewall.allowedTCPPorts = [ 47984 47989 47990 48010 ];
  networking.firewall.allowedUDPPorts = [ 47998 47999 48000 48002 48010 ];

  # ── Fake udev stubs ───────────────────────────────────────────────────────────

  # libinput and libudev expect /run/udev/data and /run/udev/control to exist.
  # vuinputd forwards real udev events into the container, but these stubs must
  # still be present for applications to initialise their udev connections.
  systemd.services.fake-udev = {
    description = "Create /run/udev stubs required by libinput and libudev";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "basic.target" ];
    before      = [ "user@${toString userId}.service" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = lib.getExe fakeUdev;
    };
  };

  # ── DRI group GID matching ────────────────────────────────────────────────────

  # See setupDriGroups in the let block above for details.
  systemd.services.setup-dri-groups = {
    description = "Match render/video group GIDs to host /dev/dri device GIDs";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "basic.target" ];
    before      = [ "user@${toString userId}.service" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = lib.getExe setupDriGroups;
    };
  };

  # ── vuinputd dependency ───────────────────────────────────────────────────────

  # /dev/uinput inside the container is bind-mounted from /dev/vuinput on the
  # host by nspawn (see README). This service gates the entire user session
  # until that device is present, which means vuinputd must be running on the
  # host before the container is started. If the host nspawn service already
  # declares After=vuinputd.service, this is a belt-and-suspenders check.
  systemd.services.wait-for-uinput = {
    description = "Wait for /dev/uinput (provided by host vuinputd)";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "fake-udev.service" ];
    before      = [ "user@${toString userId}.service" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = 30;
      ExecStart       = lib.getExe waitForUinput;
    };
  };

  # ── Pipewire ──────────────────────────────────────────────────────────────────

  # Pipewire runs as part of the user session via socket activation. It starts
  # in parallel with labwc and is always ready before sunshine needs audio.
  services.pipewire = {
    enable             = true;
    wireplumber.enable = true;
    audio.enable       = true;
    pulse.enable       = true;
  };

  # ── Headless labwc ────────────────────────────────────────────────────────────

  # Type=notify means sunshine.service only starts once labwc signals READY=1
  # from its autostart script — after the Wayland socket is accepting
  # connections. NotifyAccess=all is required because the notify comes from
  # the autostart child process, not from labwc itself.
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

  # ── Sunshine ──────────────────────────────────────────────────────────────────

  # pkgs.sunshine is fetched from the Nix binary cache automatically —
  # no manual download or compilation needed (see file header).
  # We define the service from scratch rather than using services.sunshine
  # so there is no conflict with the upstream service file, which assumes a
  # graphical desktop session and adds a sleep 5 startup delay.
  systemd.user.services.sunshine = {
    description = "Sunshine game streaming server";
    wantedBy    = [ "default.target" ];
    after       = [ "headless-labwc.service" "pipewire.service" ];
    requires    = [ "headless-labwc.service" ];
    environment = {
      WAYLAND_DISPLAY = "wayland-0";
    };
    serviceConfig = {
      Type                  = "simple";
      ExecStart             = lib.getExe pkgs.sunshine;
      Restart               = "on-failure";
      RestartSec            = "2s";
      StartLimitIntervalSec = 30;
      StartLimitBurst       = 5;
    };
  };
}
