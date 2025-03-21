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
    {
      apps.genCerts = {
        type = "app";
        program = import ./gen-certs.nix pkgs machines;
      };
      apps.showCert = {
        type = "app";
        program = toString (pkgs.writers.writeBash "show-cert" ''
          if [[ $# != 1 ]]; then
             echo "ERROR: Specify certificate argument"
             exit 1
          fi
          CERT="$1"
          ${pkgs.openssl}/bin/openssl x509 -text -noout -in "$CERT"
        '');
      };
      apps.deploy = {
        type = "app";
        program =
          toString (pkgs.writers.writeBash "deploy" ''
            function exists_in_list() {
                  LIST=$1
                  DELIMITER=$2
                  VALUE=$3
                  echo $LIST | tr "$DELIMITER" '\n' | grep -F -q -x "$VALUE"
            }
            if [[ $# != 1 ]]; then
                echo "ERROR: Specify target machine"
                exit 1
            fi
            MACHINE="$1"
            if exists_in_list "${builtins.concatStringsSep " " (pkgs.lib.attrNames machines)}" " " "$MACHINE"; then
                echo "Machine exists"
                exec nix run github:nix-community/nixos-anywhenixos-anywhere --
                -flake .#balthazar --generate-hardware-config
                nixos-generate-config ./hardware-configuration.nix $MACHINE
                nixos@machines.$MACHINE.ip
                exit 1
            else
                echo "Machine does not exist"
                exit 1
            fi
          '');
      };
      nixosConfigurations = pkgs.lib.genAttrs (pkgs.lib.attrNames machines)
        (name: nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit machines; };
          modules = [
            { networking.hostName = name; }
            disko.nixosModules.disko
            ./shared/configuration.nix
            ./hardware-configuration.nix
            ./shared/disk-config.nix
            ./shared/kube-vip.nix
            sops-nix.nixosModules.sops
            # This line will populate NIX_PATH
            { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
          ];
        }
        );

      # Use this for all other targets
      # nixos-anywhere --flake .#generic-nixos-facter --generate-hardware-config nixos-generate-config ./hardware-configuration.nix <hostname>
      # nixosConfigurations = {
      #   generic = nixpkgs.lib.nixosSystem {
      #     system = "x86_64-linux";
      #     modules = [
      #       disko.nixosModules.disko
      #       ./shared/configuration.nix 
      #       ./hardware-configuration.nix
      #       ./shared/disk-config.nix
      #       sops-nix.nixosModules.sops
      #       # This line will populate NIX_PATH
      #       { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
      #     ];
      #   };
      # };
      # {
      #   balthazar = nixpkgs.lib.nixosSystem {
      #     system = "x86_64-linux";
      #     modules = [
      #       disko.nixosModules.disko
      #       ./shared/configuration.nix
      #       ./hardware-configuration.nix
      #       ./shared/disk-config.nix
      #       ./unique/thinkcentre.nix
      #       sops-nix.nixosModules.sops
      #       # This line will populate NIX_PATH
      #       { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
      #     ];
      #   };
      #   melchior-kube = nixpkgs.lib.nixosSystem {
      #     system = "x86_64-linux";
      #     modules = [
      #       disko.nixosModules.disko
      #       ./shared/configuration.nix
      #       ./hardware-configuration.nix
      #       ./shared/disk-config-virtual.nix
      #       ./unique/melchior.nix
      #       sops-nix.nixosModules.sops
      #       # This line will populate NIX_PATH
      #       { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
      #     ];
      #   };
    };
}
