{ modulesPath
, lib
, pkgs
, config
, machines
, ...
}:
with builtins;  with pkgs.lib;
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./script.nix
  ];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  # boot.loader.efi.canTouchEfiVariables = true;

  environment.systemPackages = with pkgs; map lib.lowPrio [
    curl
    gitMinimal
    neovim
    wget
    kubecfg
    kubectl
    kubernetes
    powertop
    pciutils
    btop
    dig # network toubleshooting
    fastfetch
    openssl
    cfssl
    certmgr
    jq
    cri-tools
    ethtool
    conntrack-tools
    iptables
    kubernetes-helm
    helmfile
    helmsman
    cifs-utils
    nfs-utils
    nftables
    openiscsi
    libnfs
    smartmontools
    zlib
  ];

  #boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      update =
        "cd ~/Magi; nix flake update --commit-lock-file";
      edit = "cd ~/Magi; vim .; cd $OLDPWD";
      ll = "ls -lh";
      init_dir = ''
        nix flake new -t github:nix-community/nix-direnv .
      '';
      tvim = "vim $(tv)";
      text = ''
        tv text | xargs -oI {} sh -c 'vim "$(echo {} | cut -d ":" -f 1)" +$(echo {} | cut -d ":" -f 2)' '';
      tgit = "cd $(tv git-repos)";
      rebuild =
        "sudo nixos-rebuild --flake ~/Magi#${config.system.name} switch";
      # etcdctl = ''
      #   etcdctl
      #   --cert="/var/lib/kubernetes/secrets/etcd-${config.system.name}-client.pem"
      #   --cacert="/var/lib/kubernetes/secrets/ca.pem"
      #   --key="/var/lib/kubernetes/secrets/etcd-${config.system.name}-client-key.pem"
      #   --server=127.0.0.1:2379
      # '';
      k = "sudo kubectl";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "direnv"
      ];
      theme = "half-life";
    };
    shellInit = ''
      export PATH="$HOME/.cargo/bin:$PATH";
    '';
  };
  programs.neovim = {
    enable = true;
    defaultEditor = true;

    # Enable other frameworks for plugins.
    withNodeJs = true;
    withPython3 = true;
    withRuby = true;

    # Setup aliasing.
    viAlias = true;
    vimAlias = true;
  };
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
  networking = {
    extraHosts = ''${machines.kubeMaster.ip} ${toString machines.kubeMaster.name}
    '';
    dhcpcd.enable = true;
    # interfaces.ens18.ipv4.addresses = [{ address = "192.168.88.30"; prefixLength = 28; }];
    vlans = {
      kubernetes = {
        id = 100;
        interface = machines.${config.system.name}.interface;
        # Kijk in de installer welke interface het gaat worden en stel dat dan
        # goed in.
      };
      longhorn = {
          id = 500;
          interface = machines.${config.system.name}.longhornInterface;
      };
    };
    interfaces.kubernetes.ipv4.addresses = [{
      address = machines.${config.system.name}.ip;
      prefixLength = 24;
    }];
    interfaces.longhorn.ipv4.addresses = [{
      address = machines.${config.system.name}.longhornIP;
      prefixLength = 24;
    }];
    interfaces.kubernetes.ipv4.routes = [
    {
	    address = "0.0.0.0";
	    prefixLength = 0;
	    via = "10.13.13.1";
    }
    ];
    firewall.trustedInterfaces = [ "cni+" ];
    firewall = {
        enable = false;
        allowedTCPPorts = [ 
        80
        443
	53
        22
        6443 #apiserver
        2379 #etcd
        2380 #etcd
        7946 #metallb speaker
        179 #BGP
        9099 #HEALTH check
        10250 #kubernetes metrics server
        ];
        allowedUDPPorts = [ 
        80
        443
	53
        8472 
        ];

    };
    nameservers = [ machines.kubeMaster.gateway ];
  };
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      AllowUsers = [ "admin" "root"];
      PermitRootLogin = "yes";
    };
#j    listenAddresses = [{
#	addr = machines.${config.system.name}.ip;
#	port = 22;
#
#    }];
  };
  services.home-assistant = {
    enable = machines.${config.system.name}.hass;
    config = {
      homeassistant = {
        name = "Home";
        unit_system = "metric";
        time_zone = "UTC";
	#server_host = machines.${config.system.name}.localIp;
      };
      http = {
	server_host = machines.${config.system.name}.localIp;

	};
      frontend = {
        themes = "!include_dir_merge_named themes";
      };
      network = {
	bind_interface = machines.${config.system.name}.interface;
      };
      zeroconf = {
	interface = machines.${config.system.name}.interface;
      };
    };
    package = pkgs.home-assistant.override {
      extraPackages = python3Packages: with python3Packages; [
        psycopg2
        zlib-ng
        isal
      ];
      extraComponents = [
        "default_config"
        "esphome"
        "met"
        "hardware"
	"homeassistant_hardware"
        "androidtv_remote"
	"mikrotik"
	"zha"
      ];
    }
    ;
  };

    # Fixes for longhorn
  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
  ];
  virtualisation.docker.logDriver = "json-file";

  services.tailscale.enable = true;
  services.openiscsi = {
    enable = true;
    name = "iqn.2016-04.com.open-iscsi:${config.system.name}";
  };
  services.k3s = {
      enable = true;
      role = "server";
      tokenFile = "/home/admin/token";
      clusterInit = machines.${config.system.name}.master;
      serverAddr = if (machines.${config.system.name}.master == false) then
                  "https://${machines.kubeMaster.ip}:6443" else "";
      extraFlags = [ 
      "--debug" 
      "--advertise-address=${machines.${config.system.name}.ip}"
      "--node-ip=${machines.${config.system.name}.ip}"
      "--node-external-ip=${machines.${config.system.name}.ip}"
      "--disable servicelb"
      "--disable traefik"
      "--disable local-storage"
      ];
  };
  services.xserver.videoDrivers = if (machines.${config.system.name}.nvidia)
  then [ 
    "nvidia"
  ] else
  [];
  services.ollama = if (machines.${config.system.name}.nvidia ) then {
        enable = true;
        host = machines.${config.system.name}.ip;
        package = pkgs.ollama-cuda;
        acceleration = "cuda";
  } else
  {
        enable = false;
  };
  services.llama-cpp = if (machines.${config.system.name}.nvidia ) then {
        enable = true;
        host = machines.${config.system.name}.ip;
        model = "-hf mradermacher/bge-reranker-v2-gemma-i1-GGUF:Q4_K_M";
  } else
  {
        enable = false;
  };
  nixpkgs.config.allowUnfree = if (machines.${config.system.name}.nvidia ==
  true) then true else false;
  hardware.graphics.enable = true;
  hardware.nvidia = {
        powerManagement.enable = true;
        powerManagement.finegrained = false;
        open = true;
      }; 

  virtualisation.docker.enable = true;
  users.users.admin = {
    isNormalUser = true;
    hashedPassword =
    "$6$/yVriAI3PtuzlZ8y$cx2HNFZ43EU/bNbT36shbepwXWJxbI2/hjm9hsKCR7sf7Yldspr7xswDwzTZzma69QDzNsQHMMVTjFDC66XI1/";
    extraGroups = [ "wheel" "docker" "kubernetes" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPsp/GP+FOMXJmr34gO5055gqvlAF7Q/QK72XXBIa6O tadesalverda@outlook.com"
      ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPsp/GP+FOMXJmr34gO5055gqvlAF7Q/QK72XXBIa6O tadesalverda@outlook.com"
  ];
  # we want immutable users
  # because this makes the system fully reproducible, nothing should be configured on the command line
  users.mutableUsers = false;

  system.stateVersion = "24.05";
}
