# Python container — minimal server for running simulations
# CPU: 4 cores (400%), no memory limit, no GPU

{ config, pkgs, lib, ... }:

{
  system.stateVersion = "24.05";
  boot.isContainer = true;
  nixpkgs.config.allowUnfree = true;

  # ── User ──────────────────────────────────────────────────────────────────────

  users.users.python = {
    isNormalUser = true;
    uid = 1000;
    extraGroups = [ "users" ];
  };

  # ── Packages ──────────────────────────────────────────────────────────────────

  environment.systemPackages = with pkgs; [
    python3
    git
    s3fs
  ];

  # ── S3 Mount ──────────────────────────────────────────────────────────────────

  # Create /data directory and s3fs credentials
  environment.etc."passwd.s3fs".text = ''
    s3fs:GK3bfa4220798c832f541682c4:b72f07e05e06f73f17a81f0cf99c8661a299593a58808d138935acf669b4c72a
  '';
  environment.etc."passwd.s3fs".mode = "0600";

  systemd.mounts = [
    {
      where = "/data";
      what = "ilse";
      type = "fuse.s3fs";
      options =
      "allow_other,uid=1000,gid=1000,umask=022,url=http://10.13.13.6:3900,use_ssl=false,path_style=true";
      unitConfig.After = [ "network-online.target" ];
      unitConfig.Requires = [ "network-online.target" ];
      unitConfig.DefaultDependencies = false;
    }
  ];

  # ── Networking ────────────────────────────────────────────────────────────────

  networking.useNetworkd = true;
  networking.useHostResolvConf = lib.mkForce false;
  services.resolved.enable = true;
}
