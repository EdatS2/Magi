{ modulesPath
, lib
, pkgs
, config
, osConfig
, ...
}:
let
  kubeMasterIP = "10.13.13.3";
  kubeMasterHostname = "balthazar";
  kubeMasterAPIServerPort = 6443;
  kubeGateway = "10.13.13.1";
  kubeNetwork = {
    balthazar = "10.13.13.3";
    melchior-kube = "10.13.13.2";
    gaspard-kube = "10.13.13.4";
  };

  apiEtcdServers = map (p: "https://${p}:2379")
    (lib.attrValues kubeNetwork);
  hostIP = (builtins.elemAt
    config.networking.interfaces.kubernetes.ipv4.addresses 0).address;

  etcdUrlsClients = builtins.concatLists [
    (map (p: "https://${p}:2379")
      [ hostIP ])
    [ "https://127.0.0.1:2379" ]
  ];
  etcdUrlsPeer = builtins.concatLists [
    (map (p: "https://${p}:2380")
      [ hostIP ])
    [ "https://127.0.0.1:2380" ]
  ];
  # hier moet ook hostname bij
  etcdInit = builtins.attrValues
  (builtins.mapAttrs (name: value: "${name}=https://${value}:2380")
  kubeNetwork);

    in
    {
    imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./script.nix
    ./kube-vip.nix
    ];
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  # boot.loader.efi.canTouchEfiVariables = true;
  services.openssh.enable = true;

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
  ];

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
    extraHosts = ''${kubeMasterIP} ${kubeMasterHostname}
    '';
    dhcpcd.enable = true;
    # interfaces.ens18.ipv4.addresses = [{ address = "192.168.88.30"; prefixLength = 28; }];
    vlans = {
      kubernetes = {
        id = 100;
      };
    };
    firewall.enable = false;
    nameservers = [ kubeGateway ];
  };
  services.kubernetes = {
    # disabled kubernetes to focus on DNS and networking first
    roles = [ "master" "node" ];
    masterAddress = kubeMasterHostname;
    apiserverAddress = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
    pki = {
      enable = true;
      # todo add extra san
      cfsslAPIExtraSANs = lib.attrNames kubeNetwork;
    };
    apiserver = {
      securePort = kubeMasterAPIServerPort;
      advertiseAddress = kubeMasterIP;
      # just need ip's here
      etcd.servers = apiEtcdServers;
    };
    addons.dns.enable = true;
    kubelet.nodeIp = hostIP;
  };
  services.etcd = {
    # generator expressions from kubeNodesIP
    listenPeerUrls = etcdUrlsPeer;
    listenClientUrls = etcdUrlsClients;
    advertiseClientUrls = etcdUrlsClients;
    initialClusterState = "new";
    initialCluster = etcdInit;
  };

  virtualisation.docker.enable = true;
  users.users.admin = {
    isNormalUser = true;
    hashedPassword = "$6$mtwy4csazokFBG0W$JRlXuJlVToMHFDEshNZeKbooow0lV9xPqZJuWsdkRUT3dQtbpShB82IUgunO/g6DWsLHDbzXv.fJExJXgvrzq0";
    extraGroups = [ "wheel" "docker" "kubernetes" ];
    shell = pkgs.zsh;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAPsp/GP+FOMXJmr34gO5055gqvlAF7Q/QK72XXBIa6O tadesalverda@outlook.com"
  ];
  # we want immutable users
  # because this makes the system fully reproducible, nothing should be configured on the command line
  users.mutableUsers = false;

  system.stateVersion = "24.05";
  }
