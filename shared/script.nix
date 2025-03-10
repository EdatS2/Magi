{ pkgs, ... }:
let
  fetchScript = ''
    #!/bin/bash
    # Configuration
    REMOTE_NAME = "origin";

    # Change directory to your repository

    # Fetch updates from the remote repository without changing local files
    ${pkgs.git}/bin/git fetch "$REMOTE_NAME"

    # Check if there are new commits in the main branch (modify 'main' as needed)
    NEW_COMMITS=$(${pkgs.git}/bin/git log --oneline "HEAD..$REMOTE_NAME/main" | wc -l)

    if [ "$NEW_COMMITS" -gt 0 ]; then
        echo "There are new commits. Pulling changes..."
        ${pkgs.git}/bin/git pull origin main
        echo "Pull successful."
    else
        echo "No new commits detected."
    fi

    exit 0
  '';

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

}

