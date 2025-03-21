pkgs:
with builtins; with pkgs.lib;
{
  balthazar = {
    ip = "10.13.13.3";
    kubernetes.enable = true;
    etcd.enable = true;
    node = true;
  };
  melchior-kube = {
    ip = "10.13.13.2";
    kubernetes.enable = true;
    etcd.enable = true;
    node = true;
  };
  gaspard-kube = {
    ip = "10.13.13.4";
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
