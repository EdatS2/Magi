{ 
pkgs
, ...
}:
{
   networking = {
       hostName = "melchior-kube"; 
        # Kijk in de installer welke interface het gaat worden en stel dat dan
        # goed in.
       vlans.kubernetes.interface = "ens18"; 
       interfaces.kubernetes.ipv4.addresses = [{ address = "10.13.13.2";
       prefixLength = 24; }];       
   };
   programs.zsh.shellAliases =  {
      rebuild =
        "sudo nixos-rebuild --flake ~/Magi#melchior-kube switch";
   };
   environment.systemPackages = with pkgs; [
   ];
}
