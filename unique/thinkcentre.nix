{ 
pkgs
, ...
}:
{
   networking = {
       vlans.kubernetes.interface = "eno1"; 
       interfaces.kubernetes.ipv4.addresses = [{ address = "10.13.13.3";
       prefixLength = 24; }];       
        # Kijk in de installer welke interface het gaat worden en stel dat dan
        # goed in.
   };
   programs.zsh.shellAliases =  {
      rebuild =
        "sudo nixos-rebuild --flake ~/Magi#balthazar switch";
   };
   environment.systemPackages = with pkgs; [
        libva-utils
   ];
   hardware.graphics.enable = true;
}
