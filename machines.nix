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
  };
  gaspard = {
    ip = "10.13.13.2";
    localIp = "192.168.88.107";
    interface = "eno1";
    longhornInterface = "enp0s20f0u2";
    longhornIP = "10.20.20.2";
    disk = "/dev/nvme0n1";
    kubernetes.enable = true;
    etcd.enable = true;
    node = true;
    master = false;
    nvidia = true;
    hass = false;
    octo = false;
  };
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
  };
  kubeMaster = {
      ip = "10.13.13.3";
      gateway = "10.13.13.1";
      port = 6443;
      name = "kubernetes";
  };
}
