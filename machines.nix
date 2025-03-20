pkgs:
with builtins; with pkgs.lib;
{
  balthazar = {
    ip = "10.13.13.3";
    kubernetes.enable = true;
    etcd.enable = true;
  };
  melchior-kube = {
    ip = "10.13.13.2";
    kubernetes.enable = true;
    etcd.enable = true;
  };
  gaspard-kube = {
    ip = "10.13.13.4";
    #node not yet created
    kubernetes.enable = false;
    etcd.enable = false;
  };
}
