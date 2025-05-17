{ pkgs, lib, ... }:
let
  fetchScript = ''
    #!/bin/bash
    # Configuration

    # Change directory to your repository

    # Fetch updates from the remote repository without changing local files
    git fetch origin

    # Check if there are new commits in the main branch (modify 'main' as needed)
    NEW_COMMITS=$(git log --oneline "HEAD..origin/main" | wc -l)

    if [ "$NEW_COMMITS" -gt 0 ]; then
        echo "There are new commits. Pulling changes..."
        git pull origin main
        echo "Pull successful."
    else
        echo "No new commits detected."
    fi

    exit 0
  '';
  permissionScript = ''
    #!/bin/bash
    chown kubernetes:kubernetes *-key.pem
    chown etcd:kubernetes etcd-*-key.pem
    chmod 644 *-key.pem 
# set correct write read permissions
  '';
    kubeConfigWriter = '' 
    echo ${(builtins.toJSON {
    apiVersion = "v1";
    kind = "Config";
    clusters = [
    {
        cluster = {
            certificate-authority = "/var/lib/kubernetes/secrets/ca.pem";
            server = "https://127.0.0.1:6443";
        };
        name = "Salverda";
    }
    ];
    contexts = [
    {
        context = {
            cluster = "Salverda";
            user = "admin";
        };
        name = "dev-context";
    }
    ];
    current-context = "dev-context";
    users = [
    {
        name = "admin";
        user = {
            client-certificate = "/var/lib/kubernetes/secrets/kubernetes-admin.pem";
            client-key = "/var/lib/kubernetes/secrets/kubernetes-admin-key.pem";
        };
    }
    ];
})} > config
    chown kubernetes:kubernetes *'';
    
in
{

  # SYSTEMD service pulling the git and keeping up to date with it. Rebuilding if
  # there is a change
  systemd.services.CICD = {
    enable = true;
    # cant fetch git before we have internet
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "admin";
      WorkingDirectory = "/home/admin/Magi";
    };
    script = fetchScript;
    path = with pkgs; [
        openssh
        git
    ];
  };
  systemd.timers."run-CICD" = {
    wantedBy = [ "timers.target" ];
    enable = true;
    timerConfig = {
      # onBootSec = "1m";
      # OnUnitActiveSec = "5m";
      OnCalendar="*-*-* *:*:00 Europe/Paris";
      Unit = "CICD.service";
    };
  };
  systemd.services.Kube-certs = {
        enable = true;
        after = [ "network.target" ];
        wantedBy = [ "etcd.service" ];
        serviceConfig = {
            Type = "oneshot";
            WorkingDirectory = "/var/lib/kubernetes/secrets";
        };
        script = permissionScript;
  };
  systemd.services.Kube-config = {
        enable = true;
        after = [ "network.target" ];
        wantedBy = [ "kube-apiserver.service" ];
        serviceConfig = {
            Type = "oneshot";
            WorkingDirectory = "/var/lib/kubernetes/.kube";
        };
        script = kubeConfigWriter;
  };
}

