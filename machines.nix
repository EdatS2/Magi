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
  };
  melchior-kube = {
    ip = "10.13.13.2";
    localIp = "192.168.88.113";
    interface = "ens18";
    disk = "/dev/sda";
    kubernetes.enable = true;
    etcd.enable = true;
    node = true;
  };
  gaspard-kube = {
    ip = "10.13.13.4";
    #placeholder
    localIp = "0.0.0.0";
    #node not yet created
    kubernetes.enable = false;
    etcd.enable = false;
    node = true;
  };
  kubeMaster = {
      ip = "10.13.13.10";
      gateway = "10.13.13.1";
      port = 6443;
      name = "balthazar";
  };
}
