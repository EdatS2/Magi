{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [

  ];
  # environment.etc = {
    # nix-instantiate --eval -E 'builtins.fromJSON (builtins.readFile ./throwaway.json)' 
    # this converts json to nix
    # https://onlineyamltools.com/convert-yaml-to-json
    # "kubernetes/manifests/kube-vip.yaml".source = (pkgs.formats.yaml { }).generate "kube-config-manifest"
    services.kubernetes.kubelet.manifests.kube-vip = {
        apiVersion = "v1";
        kind = "Pod";
        metadata = {
          creationTimestamp = null;
          name = "kube-vip";
          namespace = "kube-system";
        };
        spec = {
          containers = [{
            args = [ "manager" ];
            env = [{
              name = "vip_arp";
              value = "false";
            }
              {
                name = "port";
                value = "6443";
              }
              {
                name = "vip_interface";
                value = "lo";
              }
              {
                name = "vip_cidr";
                value = "24";
              }
              {
                name = "cp_enable";
                value = "true";
              }
              {
                name = "cp_namespace";
                value = "kube-system";
              }
              {
                name = "vip_ddns";
                value = "false";
              }
              {
                name = "bgp_enable";
                value = "true";
              }
              {
                name = "bgp_routerid";
                value = "10.13.13.1";
              }
              {
                name = "bgp_as";
                value = "65000";
              }
              {
                name = "bgp_peeraddress";
              }
              {
                name = "bgp_peerpass";
              }
              {
                name = "bgp_peeras";
                value = "65000";
              }
              {
                name = "bgp_peers";
                value = "10.13.13.2:65000::false,10.13.13.3:65000::false";
              }
              {
                name = "address";
                value = "10.13.13.10";
              }];
            image = "ghcr.io/kube-vip/kube-vip:v0.3.9";
            imagePullPolicy = "Always";
            name = "kube-vip";
            resources = { };
            securityContext = {
              capabilities = {
                add = [ "NET_ADMIN" "NET_RAW" "SYS_TIME" ];
              };
            };
            volumeMounts = [{
              mountPath = "/etc/kubernetes/cluster-admin.kubeconfig";
              name = "kubeconfig";
            }];
          }];
          hostAliases = [{
            hostnames = [ "balthazar" ];
            ip = "127.0.0.1";
          }];
          hostNetwork = true;
          volumes = [{
            hostPath = {
              path = "/etc/kubernetes/cluster-admin.kubeconfig";
            };
            name = "kubeconfig";
          }];
        };
        status = { };
      };

  }
