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
    {
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
        virtual = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            disko.nixosModules.disko
            ./shared/configuration.nix
            ./hardware-configuration.nix
            ./shared/disk-config-virtual.nix
            sops-nix.nixosModules.sops
            # This line will populate NIX_PATH
            { nix.nixPath = [ "nixpkgs=${nixpkgs}" ]; }
          ];
        };
      };
    };
}
