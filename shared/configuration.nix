{
  modulesPath,
  lib,
  pkgs,
  config,
  machines,
  ...
}:
with builtins;
with pkgs.lib;
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./dev-container.nix
    (modulesPath + "/profiles/qemu-guest.nix")
    ./script.nix
    ./steam.nix
    ./llm.nix
    ./keepalived.nix
  ];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  boot.zfs = {
    # enabled = machines.${config.system.name}.zfs;
    extraPools = [ "WDred" ];
  };
  boot.supportedFilesystems.zfs = machines.${config.system.name}.zfs;
  networking.hostId = "38c2d6ec";
  # boot.loader.efi.canTouchEfiVariables = true;

  environment.systemPackages =
    with pkgs;
    map lib.lowPrio [
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
      libnfs
      smartmontools
      zlib
      hdparm
      zfs
    ];

  #boot.kernelPackages = pkgs.linuxPackages_latest;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      update = "cd ~/Magi; nix flake update --commit-lock-file";
      edit = "cd ~/Magi; vim .; cd $OLDPWD";
      ll = "ls -lh";
      init_dir = ''
        nix flake new -t github:nix-community/nix-direnv .
      '';
      tvim = "vim $(tv)";
      text = ''tv text | xargs -oI {} sh -c 'vim "$(echo {} | cut -d ":" -f 1)" +$(echo {} | cut -d ":" -f 2)' '';
      tgit = "cd $(tv git-repos)";
      rebuild = "sudo nixos-rebuild --flake ~/Magi#${config.system.name} switch";
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
    extraHosts = ''
      ${machines.kubeMaster.ip} ${toString machines.kubeMaster.name}
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
    interfaces.kubernetes.ipv4.addresses = [
      {
        address = machines.${config.system.name}.ip;
        prefixLength = 24;
      }
    ];
    interfaces.longhorn.ipv4.addresses = [
      {
        address = machines.${config.system.name}.longhornIP;
        prefixLength = 24;
      }
    ];
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
        6443 # apiserver
        6444 # idk what this is
        2379 # etcd
        2380 # etcd
        7946 # metallb speaker
        179 # BGP
        9099 # HEALTH check
        6800 #haproxy
        10250 # kubernetes metrics server
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
  services.smartd = {
    enable = false;
    autodetect = true;
    defaults.autodetected = "-a -n standby,idle -s
      (S/../.././02|L/../01/./04)";
    notifications = {
      test = true;
      mail = {
        sender = config.system.name;
        recipient = "tade@salverdaserver.nl";
        enable = true;
      };
    };
  };
  systemd.services.hddspindown = {
    enable = machines.${config.system.name}.zfs;
    after = [ "systemd-remount-fs.service" ];
    wants = [ "local-fs.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = ''
        ${pkgs.hdparm}/bin/hdparm -S 120 -B 120 /dev/sda /dev/sdb /dev/sdc /dev/sdd /dev/sde /dev/sdf
      '';
      RemainAfterExit = true;
    };
    startAt = "startup";
  };
  services.garage = {
    enable = machines.${config.system.name}.zfs;
    package = pkgs.garage_2;
    settings = {
      data_dir = [
        {
          capacity = "10T";
          path = "/WDred/Garage";
        }
      ];
      metadata_dir = "/var/lib/garage/meta";
      metadata_snapshots_dir = "/WDred/Garage/meta_snapshots";
      # we have a one node config
      admin = {
        admin_token = "614700bfb4d964be8f39dabdedb001562dd5aa0606a3581243a56b24ef154c05";
        api_bind_addr = "[::]:3903";
        metrics_token = "fc66162b3011e1c29cc29eb78c08d901bf11a5f3aa043a9223201beb624d6bd8";
      };
      db_engine = "sqlite";
      k2v_api = {
        api_bind_addr = "[::]:3904";
      };
      replication_factor = 1;
      metadata_auto_snapshot_interval = "12h";
      rpc_bind_addr = "[::]:3901";
      rpc_public_addr = "127.0.0.1:3901";
      rpc_secret = "f2720f53ceb92838b555a456a4288c40f24a9c63bf007c8c30f9d6e7787e70f1";
      s3_api = {
        api_bind_addr = "[::]:3900";
        root_domain = ".s3.garage.localhost";
        s3_region = "garage";
      };
      s3_web = {
        bind_addr = "[::]:3902";
        index = "index.html";
        root_domain = ".web.garage.localhost";
      };
    };
  };

  # services.samba = {
  #   enable = machines.${config.system.name}.zfs;
  #   settings = {
  #     global = {
  #       "usershare path" = "/var/lib/samba/usershares";
  #       "usershare max" = "100";
  #       "usershare allow guests" = "yes";
  #       "usershare owner only" = "no";
  #     };
  #   };
  # };
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      AllowUsers = [
        "admin"
        "root"
        "sunshine"
      ];
      PermitRootLogin = "yes";
    };
  };
  services.octoprint = {
    enable = machines.${config.system.name}.octo;
    host = machines.${config.system.name}.ip;
    plugins =
      plugins: with plugins; [
        themeify
        stlviewer
      ];
  };
  services.home-assistant = {
    enable = machines.${config.system.name}.hass;
    config = {
      default_config = { };
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
      extraPackages =
        python3Packages: with python3Packages; [
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
        "energy"
      ];
    };
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
    serverAddr =
      if (machines.${config.system.name}.master == false) then
        "https://${machines.kubeMaster.haproxyIp}:${toString
        machines.kubeMaster.haproxyPort}"
      else
        "";
    extraFlags = [
      # "--debug"
      "--advertise-address=${machines.${config.system.name}.ip}"
      "--node-ip=${machines.${config.system.name}.ip}"
      "--node-external-ip=${machines.${config.system.name}.ip}"
      "--disable servicelb"
      "--disable traefik"
      "--disable local-storage"
      "--tls-san=${machines.kubeMaster.haproxyIp}"
    ];
  };
  services.haproxy = {
    enable = true;
    config = ''
      defaults
        mode tcp
        timeout server 1m
        timeout client 1m
        timeout connect 5s

      listen kubernetes_api
        bind "*:${toString machines.kubeMaster.haproxyPort}"
        mode tcp
        ${builtins.concatStringsSep " " (
          map (
            name:
            let
              m = machines.${name};
            in
            if m.node then "server ${name} ${m.ip}:${toString
                machines.kubeMaster.port} check \n" else ""
          ) (builtins.attrNames machines)
        )}
    '';
  };
  steam_server.enable = machines.${config.system.name}.nvidia;
  llm.enable = machines.${config.system.name}.nvidia;
  hardware.graphics.enable = true;
  hardware.nvidia =
    if (machines.${config.system.name}.nvidia == true) then
      {
        powerManagement.enable = true;
        powerManagement.finegrained = false;
        open = true;
      }
    else
      {
      };
  services.xserver.videoDrivers =
    if (machines.${config.system.name}.nvidia) then
      [
        "nvidia"
      ]
    else
      [ "modesetting" ];

  virtualisation.docker.enable = true;
  users.users.admin = {
    isNormalUser = true;
    hashedPassword = "$6$/yVriAI3PtuzlZ8y$cx2HNFZ43EU/bNbT36shbepwXWJxbI2/hjm9hsKCR7sf7Yldspr7xswDwzTZzma69QDzNsQHMMVTjFDC66XI1/";
    extraGroups = [
      "wheel"
      "docker"
      "kubernetes"
    ];
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

  sops.age.keyFile = "/etc/sops/age";
  system.stateVersion = "24.05";

}
