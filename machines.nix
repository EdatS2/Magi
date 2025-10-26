pkgs:
with builtins; with pkgs.lib;
{
  balthazar = {
    ip = "10.13.13.3";
    localIp = "192.168.88.130";
    interface = "eno1";
    longhornInterface = "enp0s20f0u2";
    longhornIP = "10.20.20.3";
    disk = "/dev/nvme0n1";
    kubernetes.enable = true;
    etcd.enable = true;
    node = true;
    master = true;
    nvidia = false;
    hass = false;
    octo = true;
    zfs = false;
  };
  # gaspard = {
  #   ip = "10.13.13.2";
  #   localIp = "192.168.88.107";
  #   interface = "eno1";
  #   longhornInterface = "enp0s20f0u2";
  #   longhornIP = "10.20.20.2";
  #   disk = "/dev/nvme0n1";
  #   kubernetes.enable = true;
  #   etcd.enable = true;
  #   node = true;
  #   master = false;
  #   nvidia = true;
  #   hass = false;
  #   octo = false;
  #   zfs = false;
  # };
  ramiel = {
    ip = "10.13.13.4";
    localIp = "192.168.88.102";
    interface = "eno1";
    longhornInterface = "enp0s20f0u7c2";
    longhornIP = "10.20.20.4";
    disk = "/dev/nvme0n1";
    kubernetes.enable = true;
    etcd.enable = true;
    node = true;
    master = false;
    nvidia = false;
    hass = true;
    octo = false;
    zfs = false;
  };
  melchior = {
    ip = "10.13.13.6";
    localIp = "192.168.88.129";
    interface = "enp5s0";
    longhornInterface = "enp0s20f0u9u1";
    longhornIP = "10.20.20.6";
    disk = "/dev/nvme1n1";
    kubernetes.enable = true;
    etcd.enable = true;
    node = true;
    master = false;
    nvidia = true;
    hass = false;
    octo = false;
    zfs = true;
  };
  kubeMaster = {
      ip = "10.13.13.3";
      gateway = "10.13.13.1";
      port = 6443;
      name = "kubernetes";
  };
}
