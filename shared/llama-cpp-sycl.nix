final: prev:

let
  inherit (prev.lib) cmakeBool cmakeFeature makeLibraryPath;

  kit = final.intel-oneapi-toolkit;

  oneapiCCUnwrapped = kit.stdenv.cc.cc.overrideAttrs (old: {
    passthru = (old.passthru or { }) // {
      langCC = true;
    };
  });

  oneapiCC = final.wrapCCWith {
    cc = oneapiCCUnwrapped;
    gccForLibs = final.gcc.cc;
    extraPackages = [ kit ];
    extraBuildCommands = ''
      ln -s $out/bin/clang++ $out/bin/icpx
      ln -s $out/bin/clang   $out/bin/icx

      echo "export CXX=\"$out/bin/icpx\"" >> $out/nix-support/setup-hook
      echo "export CC=\"$out/bin/icx\"" >> $out/nix-support/setup-hook

      echo "export ONEAPI_ROOT=\"${kit}\"" >> $out/nix-support/setup-hook
    '';
  };

  oneapiStdenv = final.overrideCC final.stdenv oneapiCC;

  icrDriversFixed =
    final.runCommand "intel-compute-runtime-drivers-igc-rpath"
      { nativeBuildInputs = [ final.patchelf ]; }
      ''
        mkdir -p $out/lib
        cp -a ${final.intel-compute-runtime}/lib/. $out/lib/
        chmod -R +w $out/lib
        find $out/lib -type f -name "*.so*" -exec \
          patchelf --add-rpath ${final.intel-graphics-compiler}/lib {} \;
      '';

  ocloc = final.runCommand "ocloc" { preferLocalBuild = true; } ''
    mkdir -p $out/bin
    for f in ${final.intel-compute-runtime.out}/bin/ocloc-*; do
      [ -f "$f" ] && cp "$f" $out/bin/ocloc && break
    done
  '';
in
{
  llama-cpp-sycl =
    (prev.llama-cpp.override {
      stdenv = oneapiStdenv;
      blasSupport = false;
      cpuArchDynamicDispatch = false;
    }).overrideAttrs
      (old: {
        pname = "llama-cpp-sycl";

        hardeningDisable = (old.hardeningDisable or [ ]) ++ [
          "fortify"
          "fortify3"
        ];

        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
          final.makeWrapper
          ocloc
        ];

        buildInputs = (old.buildInputs or [ ]) ++ [
          kit
          final.level-zero
        ];

        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          (cmakeBool "GGML_SYCL" true)
          (cmakeFeature "GGML_SYCL_TARGET" "INTEL")
          (cmakeFeature "CMAKE_PREFIX_PATH" "${kit}/compiler/latest;${kit}/mkl/latest;${kit}/dnnl/latest")
          (cmakeBool "GGML_SYCL_F16" true)
          (cmakeBool "GGML_SYCL_SUPPORT_LEVEL_ZERO_API" true)
          (cmakeFeature "LEVEL_ZERO_INCLUDE_DIR" "${final.level-zero}/include")
          (cmakeFeature "ZE_LOADER_LIB" "${final.level-zero}/lib/libze_loader.so")
          (cmakeBool "GMML_SYCL_ESIMD" true)
          # (cmakeFeature "GGML_SYCL_DEVICE_ARCH" "xe2")
        ];

        env = (old.env or { }) // {
          MKLROOT = "${kit}/mkl/latest";
        };

        postInstall =
          builtins.replaceStrings
            [
              "installShellCompletion --cmd llama-server --bash <($out/bin/llama-server --completion-bash)"
            ]
            [ ": # shell completion skipped: SYCL llama-server aborts without a GPU" ]
            (old.postInstall or "");

        postFixup = (old.postFixup or "") + ''
          for f in $out/bin/*; do
            [ -L "$f" ] && continue
            [ -f "$f" ] && [ -x "$f" ] || continue
            wrapProgram "$f" --prefix LD_LIBRARY_PATH : \
              ${makeLibraryPath [
                icrDriversFixed
                final.level-zero
              ]}
          done
        '';
      });
}
