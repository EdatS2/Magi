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
            name = "vip_nodename";
            valueFrom = {
              fieldRef = {
                fieldPath = "spec.nodeName";
              };
            };
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
            name = "dns_mode";
            value = "first";
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
            name = "svc_enable";
            value = "true";
          }
          {
            name = "svc_leasename";
            value = "plndr-svcs-lock";
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
            value = "192.168.0.10:65000::false,192.168.0.11:65000::false";
          }
          {
            name = "address";
            value = "10.13.13.10";
          }
          {
            name = "prometheus_server";
            value = ":2112";
          }];
        image = "ghcr.io/kube-vip/kube-vip:v0.8.9";
        imagePullPolicy = "IfNotPresent";
        name = "kube-vip";
        resources = { };
        securityContext = {
          capabilities = {
            add = [ "NET_ADMIN" "NET_RAW" ];
          };
        };
        volumeMounts = [{
          mountPath = "/etc/kubernetes/admin.conf";
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
