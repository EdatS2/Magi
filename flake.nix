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
      machines = import ./machines.nix nixpkgs;
    in
    {
      apps.genCerts = {
        type = "app";
        program = import ./gen-certs.nix nixpkgs machines;
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

      # Use this for all other targets
      # nixos-anywhere --flake .#generic-nixos-facter --generate-hardware-config nixos-generate-config ./hardware-configuration.nix <hostname>
      nixosConfigurations = {
        generic = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ./shared/configuration.nix
            ./hardware-configuration.nix
            ./shared/disk-config.nix
            sops-nix.nixosModules.sops
            # This line will populate NIX_PATH
            { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
          ];
        };
        balthazar = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ./shared/configuration.nix
            ./hardware-configuration.nix
            ./shared/disk-config.nix
            ./unique/thinkcentre.nix
            sops-nix.nixosModules.sops
            # This line will populate NIX_PATH
            { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
          ];
        };
        melchior-kube = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ./shared/configuration.nix
            ./hardware-configuration.nix
            ./shared/disk-config-virtual.nix
            ./unique/melchior.nix
            sops-nix.nixosModules.sops
            # This line will populate NIX_PATH
            { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
          ];
        };
      };
    };
}
