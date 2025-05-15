pkgs: machines:
with pkgs; with pkgs.lib;
toString (writers.writeBash "deploy" ''
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
  if [ -e "./certs" ]; then 
      echo "found certs"
      temp=$(mktemp -d)
      cleanup() {
          rm -rf "$temp"
      }
      trap cleanup EXIT

      install -d -m755 "$temp/var/lib/kubernetes/secrets"
      cp ./certs/ssl/* $temp/var/lib/kubernetes/secrets
      echo "copied $(ls -1 $temp/var/lib/kubernetes/secrets | wc -l) certs to temp folder"
  MACHINE="$1"
  if exists_in_list "${builtins.concatStringsSep " " (attrNames machines)}" " " "$MACHINE"; then
      echo "Machine exists"
       # Get the IP address of the specified machine
        case $MACHINE in
            ${concatStringsSep "\n" (attrValues
            (mapAttrs (machineName: machine: ''
            ${machineName}) IP="${machine.localIp}";;
            '') (filterAttrs(_: machine: machine ? node)
            machines)))}
            *) echo "Not a node, ROUTER is not a valid target"; exit 1 ;;
        esac
        echo "Target at $IP"
        # currently working on it so no NIXOS anywhere step
        nix run github:nix-community/nixos-anywhere -- --extra-files "$temp" \
        --flake .#$MACHINE --generate-hardware-config \
        nixos-generate-config ./hardware-configuration.nix \
        --target-host \
        nixos@$IP 
      exit 1
  else
      echo "Machine does not exist"
      exit 1
  fi
  else
      echo "Did not find certs, generate them first?"
  fi
'')
