{
  inputs.nixpkgs.url = "nixpkgs/nixos-24.11";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.sops-nix.url = "github:Mic92/sops-nix";

  outputs =
    { nixpkgs
    , disko
    , sops-nix
    , ...
    }:
    let
      helmfile_plugins = with pkgs; wrapHelm kubernetes-helm {
        plugins = with pkgs.kubernetes-helmPlugins; [
          helm-secrets
          helm-diff
          helm-git
        ];
      };
      helmfile_override = pkgs.helmfile-wrapped.override {
          inherit (helmfile_plugins) pluginsDir;
      };
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      machines = import ./machines.nix pkgs;
    in
    with pkgs; with pkgs.lib;
    {
      apps.genCerts = {
        type = "app";
        program = import ./utils/gen-certs.nix pkgs machines;
      };
      apps.showCert = {
        type = "app";
        program = toString (writers.writeBash "show-cert" ''
          if [[ $# != 1 ]]; then
             echo "ERROR: Specify certificate argument"
             exit 
          fi
          CERT="$1"
          ${openssl}/bin/openssl x509 -text -noout -in "$CERT"
        '');
      };
      apps.deploy = {
        type = "app";
        program = import ./utils/deploy.nix pkgs machines;
      };
      apps.update = {
        type= "app";
        program = toString (writers.writeBash "update" ''
          if [[ $# != 1 ]]; then
             echo "ERROR: Specify machine argument"
             exit 
          fi
       # Get the IP address of the specified machine
            case $1 in
                ${concatStringsSep "\n" (attrValues
                (mapAttrs (machineName: machine: ''
                ${machineName}) IP="${machine.ip}";;
                '') (filterAttrs(_: machine: machine ? node)
                machines)))}
                *) echo "Not a node, ROUTER is not a valid target"; exit 1 ;;
            esac
            echo "Target at $IP"
          nixos-rebuild switch --flake "$PWD#$1" --target-host root@$IP
          exit 1
        '');
      };
      nixosConfigurations = genAttrs (attrNames machines)
        (name: nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit machines; };
          modules = [
            { networking.hostName = name; }
            disko.nixosModules.disko
            ./shared/configuration.nix
            ./hardware-configuration.nix
            # for maintance
            ./shared/disk-config.nix
            ./shared/kube-vip.nix
            sops-nix.nixosModules.sops
            # This line will populate NIX_PATH
            { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
          ];
        }
        );
        # shell to connect with your cluster and manage it
    devShells.x86_64-linux.default = pkgs.mkShell {
        packages = with pkgs; [
            kubectl
            kustomize
            kustomize-sops
            k9s
            apacheHttpd
            sops
        ] ++
        [(wrapHelm kubernetes-helm {
            plugins = with pkgs.kubernetes-helmPlugins; [
                helm-diff
                helm-git
                helm-secrets
            ];
        })] ++
        [
            helmfile_plugins
            helmfile_override
        ];
        shellHook = ''
            export KUBECONFIG=./k3s.yaml
        '';
    };

    };
}
