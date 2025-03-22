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
  MACHINE="$1"
  if exists_in_list "${builtins.concatStringsSep " " (attrNames machines)}" " " "$MACHINE"; then
      echo "Machine exists"
       # Get the IP address of the specified machine
        case $MACHINE in
            ${concatStringsSep "\n" (attrValues
            (mapAttrs (machineName: machine: ''
            ${machineName}) IP="${machine.ip}";;
            '') (filterAttrs(_: machine: machine ? node)
            machines)))}
            *) echo "Not a node, ROUTER is not a valid target"; exit 1 ;;
        esac
        echo "Target at $IP"
        # currently working on it so no NIXOS anywhere step
        # nix run github:nix-community/nixos-anywhere -- \
        # --flake .#$MACHINE --generate-hardware-config \
        # nixos-generate-config ./hardware-configuration.nix \
        # --target-host \
        # nixos@$IP 
      exit 1
  else
      echo "Machine does not exist"
      exit 1
  fi
'')
