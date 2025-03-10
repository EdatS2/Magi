{ pkgs, ... }:
let
        # Configuration
  REPO_PATH = "/home/admin/Magi";
  REMOTE_NAME = "origin";
  fetchScript = ''
    #!/bin/bash

    # Change directory to your repository
        cd "${REPO_PATH}" || exit

    # Fetch updates from the remote repository without changing local files
        git fetch "$REMOTE_NAME"

    # Check if there are new commits in the main branch (modify 'main' as needed)
          NEW_COMMITS=$(git log --oneline "HEAD..${REMOTE_NAME} /main" | wc -l)

          if [ "$NEW_COMMITS" -gt 0 ]; then
          echo "There are new commits. Pulling changes..."
          git pull origin main
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
    };
    script = fetchScript;
    confinement.packages = pkgs.git;
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

