{ 
pkgs
, ...
}:
{
   networking = {
       hostName = "melchior-kube"; 
       vlans.kubernetes.interface = "eno1"; 
       interfaces.kubernetes.ipv4.addresses = [{ address = "10.13.13.2";
       prefixLength = 24; }];       
        # Kijk in de installer welke interface het gaat worden en stel dat dan
        # goed in.
   };
   programs.zsh.shellAliases =  {
      rebuild =
        "sudo nixos-rebuild --flake ~/Magi#melchior-kube switch";
   };
   environment.systemPackages = with pkgs; [
   ];
}
