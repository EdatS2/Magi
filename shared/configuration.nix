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
      rebuild =
        "sudo nixos-rebuild --flake ~/Magi#${config.system.name} switch";
      etcdctl = ''
        etcdctl
        --cert="/var/lib/kubernetes/secrets/etcd-${config.system.name}-client.pem"
        --cacert="/var/lib/kubernetes/secrets/ca.pem"
        --key="/var/lib/kubernetes/secrets/etcd-${config.system.name}-client-key.pem"
        --server=127.0.0.1:2379
      '';
      k = "kubectl";
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
    };
    interfaces.kubernetes.ipv4.addresses = [{
      address = machines.${config.system.name}.ip;
      prefixLength = 24;
    }];
    firewall.enable = false;
    nameservers = [ machines.kubeMaster.gateway ];
  };
  services.k3s = {
      enable = true;
      role = "server";
      tokenFile = "/root/token";
      clusterInit = machines.${config.system.name}.master;
      serverAddr = "https://${machines.kubeMaster.ip}:6443";
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
