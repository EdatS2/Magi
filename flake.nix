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
            helmfile
            kubernetes-helm
            kustomize
        ];
        shellHook = ''
            export KUBECONFIG=./k3s.yaml

        '';
    };

    };
}
