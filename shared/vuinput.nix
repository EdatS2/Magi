{
  pkgs ? import <nixpkgs> { },
}:
let
  src = pkgs.fetchFromGitHub {
    owner = "joleuger";
    repo = "vuinputd";
    rev = "b9b4d1a";
    sha256 = "sha256-eatTqd7A8ZQ7+CeEgGE8J7OAILCXshgq1GUm/Byeeok=";
  };
in
{
  vuinputd = pkgs.rustPlatform.buildRustPackage rec {
    pname = "vuinputd";
    version = "0.3.2";
    inherit src;

    nativeBuildInputs = [
      pkgs.pkg-config
      pkgs.llvmPackages_21.libclang.lib
      pkgs.glibc.dev
    ];

    cargoLock.lockFile = "${src}/Cargo.lock";

    buildInputs = [
      pkgs.fuse3
      pkgs.udev.dev
    ];

    LIBCLANG_PATH = "${pkgs.llvmPackages_21.libclang.lib}/lib";
    BINDGEN_EXTRA_CLANG_ARGS = "-I ${pkgs.glibc.dev}/include";

    cargoBuildArgs = [ "--release" ];

    doCheck = false;

    preInstall = ''
      mkdir -p $out/etc/udev/rules.d
      cp vuinputd/udev/90-vuinputd-protect.rules $out/etc/udev/rules.d/
      cp vuinputd/udev/90-vuinputd.hwdb $out/etc/udev/rules.d/
    '';

    meta = {
      description = "Container-safe mediation daemon for /dev/uinput using CUSE";
      homepage = "https://github.com/joleuger/vuinputd";
      license = pkgs.lib.licenses.mit;
      maintainers = [ ];
      platforms = pkgs.lib.platforms.linux;
    };
  };
}
