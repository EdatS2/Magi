pkgs:
with builtins; with pkgs.lib;
{
  balthazar = {
    ip = "10.13.13.3";
    localIp = "192.168.88.130";
    interface = "eno1";
    disk = "/dev/nvme0n1";
    kubernetes.enable = true;
    etcd.enable = true;
    node = true;
    master = true;
  };
  melchior-kube = {
    ip = "10.13.13.2";
    localIp = "192.168.88.113";
    interface = "ens18";
    disk = "/dev/sda";
    kubernetes.enable = true;
    etcd.enable = true;
    node = true;
    master = false;
  };
  ramiel = {
    ip = "10.13.13.4";
    localIp = "192.168.88.102";
    interface = "eno1";
    disk = "/dev/nvme0n1";
    kubernetes.enable = true;
    etcd.enable = true;
    node = true;
    master = false;
  };
  kubeMaster = {
      ip = "10.13.13.3";
      gateway = "10.13.13.1";
      port = 6443;
      name = "kubernetes";
  };
}
