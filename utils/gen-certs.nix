pkgs: machines:
with builtins; with pkgs.lib;
let
  cfssl = "${pkgs.cfssl}/bin/cfssl";
  cfssljson = "${pkgs.cfssl}/bin/cfssljson";
  profiles = [
    { name = "auth-only"; }
    { name = "auth-and-cert-sign"; extra = [ "cert sign" ]; }
  ];
  caName = "demo-ca";
  caConf = pkgs.writeText "${caName}-conf.json" (toJSON
    {
      signing = {
        profiles = listToAttrs (map
          ({ name, extra ? [ ] }:
            nameValuePair
              name
              {
                usages = extra ++ [ "signing" "key encipherment" "server auth" "client auth" ];
                expiry = "87600h";
              }
          )
          profiles);
      };
    }
  );
  mkCSR = { CN, names }: pkgs.writeText "csr.json" (toJSON {
    inherit CN;
    key = { algo = "rsa"; size = 4096; };
    names = [ names ];
  });
  caCSR = mkCSR {
    CN = "Demo CA";
    names = { O = "Demo Org"; };
  };
  certificates = [
    {
      name = "kubernetes-ca";
      profile = "auth-and-cert-sign";
      CN = "Kubernetes CA Signing Key";
      names = { };
    }
    {
      name = "kubernetes";
      profile = "auth-only";
      CN = "kubernetes";
      names = { O = "Kubernetes"; };
      hostnames = [
        "kube.eu1"
        "10.33.0.1" # first IP in `--service-cluster-ip-range`
        "127.0.0.1"
        "kubernetes"
        "kubernetes.default"
        "kubernetes.default.svc"
        "kubernetes.default.svc.cluster"
        "kubernetes.svc.cluster.local"
      ] ++ concatLists
        (mapAttrsToList
          (hostname: machine: [ hostname machine.ip ])
          (filterAttrs
            (_: machine: machine ? kubernetes)
            machines));
    }
  ]
  # Kubernetes static things that we need one per-cluster
  ++ map
    ({ name, CN, O ? "Kubernetes" }:
      {
        inherit name CN;
        profile = "auth-only";
        names = { inherit O; };
      }) [
    { name = "kube-proxy-client"; CN = "front-proxy-client"; }
    { name = "kubelet-client"; CN = "system:kube-apiserver"; }
    { name = "flannel"; CN = "flannel-client"; }
    { name = "kubernetes-service-account"; CN = "service-accounts"; }
    {
      name = "kube-scheduler";
      CN = "system:kube-scheduler";
      O = "system:kube-scheduler";
    }
    {
      name = "kube-proxy";
      CN = "system:kube-proxy";
      O = "system:node-proxier";
    }
    {
      name = "kubernetes-admin";
      CN = "admin";
      O = "system:masters";
    }
    {
      name = "kube-controller-manager";
      CN = "system:kube-controller-manager";
      O = "system:kube-controller-manager";
    }
  ]
  # Kubelet certificates, one per host
  ++ mapAttrsToList
    (hostname: machine: {
      name = "kubelet-${hostname}";
      profile = "auth-only";
      CN = "system:node:${hostname}";
      names = { O = "system:nodes"; };
      hostnames = [ "kube.eu1" hostname machine.ip ];
    })
    (filterAttrs (_: machine: machine ? kubernetes) machines)
  # Etcd server certificates, one per host
  ++ mapAttrsToList
    (hostname: machine: {
      name = "etcd-${hostname}";
      profile = "auth-only";
      CN = "etcd:${hostname}";
      hostnames = [ "127.0.0.1" "localhost" hostname machine.ip ];
    })
    (filterAttrs (_: machine: machine ? etcd) machines)
  # Etcd client certificates for kubernetes masters
  ++ mapAttrsToList
    (hostname: machine: {
      name = "etcd-client-${hostname}";
      profile = "auth-only";
      CN = "etcd-client:${hostname}";
    })
    (filterAttrs (_: machine: machine ? kubernetes) machines);
in
toString (pkgs.writers.writeBash "gen-certs" ''
  if [[ $# != 1 ]]; then
     echo "ERROR: Specify directory argument"
     exit 1
  fi
  DIR="$1"
  mkdir -p "$DIR/ssl"
  cd "$DIR/ssl"
  if [[ ! -f ${caName}.pem ]]; then
     echo "### Generating CA self-signed certificate"
     ${cfssl} gencert -initca ${caCSR} | ${cfssljson} -bare ${caName}
  fi
  ${concatStringsSep "\n" (map ({profile, name, CN, names ? {}, hostnames ? []}:
    let csr = mkCSR { inherit CN names; }; in
    ''
      if [[ ! -f ${name}.pem ]]; then
          echo "### Generating certificate ${name}"
          ${cfssl} gencert \
            -ca=${caName}.pem \
            -ca-key=${caName}-key.pem \
            -config=${caConf} \
            -profile=${profile} \
            -hostname=${concatStringsSep "," hostnames} \
            ${csr} | ${cfssljson} -bare ${name}
      fi
    '') certificates)}
  echo "### Done"
'')

