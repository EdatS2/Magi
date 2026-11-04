#steam_server
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.llm.enable;
  # last updated on 18th of oktober 2026
  llama-cpp = pkgs.llama-cpp-sycl.overrideAttrs (oldAttrs: rec {
    version = "0.9.0";
    src = pkgs.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "v${version}";
      hash = "sha256-2FHjR0XXT+THe/RBXC8CXsWQ0PRa7oDzucYwhSy3/UM=";
      # hash = "sha256-0000000000000000000000000000000000000000000=";

      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    npmDepsHash = "sha256-XLtEZsSFdk+2SyfXzBp8HQ2e27PQPpDCn1YjePU1/9w=";
    # npmDepsHash = "sha256-0000000000000000000000000000000000000000000=";
    # npmRoot = "tools/ui";
    # Enable native CPU optimizations (AVX, AVX2, etc.)
    # Disable Nix's march=native stripping
  });
  # llama-swap from GitHub releases
  llama-swap = pkgs.runCommand "llama-swap" { } ''
    mkdir -p $out/bin
    tar -xzf ${
      pkgs.fetchurl {
        url = "https://github.com/mostlygeek/llama-swap/releases/download/v253/llama-swap_253_linux_amd64.tar.gz";
        hash = "sha256-kfTQr1bNVHHQEz1vidt6fbEYqc1vjs0rvf/VCqKeXrY=";
        # hash = pkgs.lib.fakeHash;
      }
    } -C $out/bin
    chmod +x $out/bin/llama-swap
  '';
in
{
  options.llm = {
    enable = lib.mkEnableOption "Enable Steam server";
  };

  config = lib.mkIf cfg {
    environment.systemPackages = [ llama-cpp ];
    # X and audio

    environment.etc."llama-swap/config.yaml".text = ''
      # llama-swap configuration
      # This config uses llama.cpp's server to serve models on demand

      models:  # Ordered from newest to oldest
        # Uploaded 2025-09-04, size 0.3 GB, max ctx: 2048, layers: 24
        "embeddinggemma:300m":
          env: 
            - "OCL_ICD_VENDORS=/run/opengl-driver/etc/OpenCL/vendors"
          cmd: |
              ${llama-cpp}/bin/llama-server
              -hf ggml-org/embeddinggemma-300M-GGUF
              --port ''${PORT}
              --embeddings
              --batch-size 2048
              --ubatch-size 2048
              --split-mode none --main-gpu 0

        # Uploaded 2026-07-31
        "Qwen:0.8B":
          env:    
            - "OCL_ICD_VENDORS=/run/opengl-driver/etc/OpenCL/vendors"
          cmd: |
              ${llama-cpp}/bin/llama-server
              -hf LiquidAI/LFM2-700M-GGUF:Q8_0
              --port ''${PORT}
              --split-mode none --main-gpu -1
              --no-mmproj
              --reasoning off
              --ctx-size 4096
              -lv 4

        # Updated 11-03-2026
        "Reranker":
          env:    
            - "OCL_ICD_VENDORS=/run/opengl-driver/etc/OpenCL/vendors"
          cmd: |
              ${llama-cpp}/bin/llama-server
              -hf ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF:Q8_0
              --port ''${PORT}
              --batch-size 2048
              --ubatch-size 2048
              --reranking
              --split-mode none --main-gpu 0

        # ADDED 15-08-2026
        "Qwen:27B": 
          env:    
            - "OCL_ICD_VENDORS=/run/opengl-driver/etc/OpenCL/vendors"
            - "ZES_ENABLE_SYSMAN=1"
            - "ONEAPI_DEVICE_SELECTOR=level_zero:0"
            - "GGML_SYCL_SPARSE_FA=1"
          cmd: | 
              ${llama-cpp}/bin/llama-server 
              -hf DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF:Q4_K_M 
              --port ''${PORT} 
              --threads 18 --jinja --ctx-size 131072 -ngl 999 
              -ctk q8_0 -ctv q8_0 
              -b 4096 -ub 2048 
              -fa 1 -lv 4 
              --split-mode none 
              -np 8
              --main-gpu 0 
              --dry-penalty-last-n 0.05 
              --kv-unified --reasoning-preserve --load-mode dio 
              -cram 16384
              --spec-type draft-mtp
              --spec-draft-n-max 3
          filters:
            setParamsByID:
               "Qwen:27B:high":
                   chat_template_kwargs:
                     reasoning_effort: high
               "Qwen:27B:xhigh":
                   chat_template_kwargs:
                       reasoning_effort: xhigh
               "Qwen:27B":
                   chat_template_kwargs:
                      reasoning_effort: medium
               "Qwen:27B:low":
                   chat_template_kwargs:
                      reasoning_effort: low

        # ADDED 15-08-2026
        "Muse": 
          env:    
            - "OCL_ICD_VENDORS=/run/opengl-driver/etc/OpenCL/vendors"
            - "ONEAPI_DEVICE_SELECTOR=level_zero:0;level_zero:1"
            - "GGML_SYCL_SPARSE_FA=1"
            - "ZES_ENABLE_SYSMAN=1"
          cmd: | 
            ${llama-cpp}/bin/llama-server 
            -hf unsloth/Muse-Glimmer-30B-GGUF:UD-Q4_K_XL
            --port ''${PORT}
            --threads 18 --jinja 
            --ctx-size 131072 -ngl 999 
            -ctk q8_0 -ctv q8_0
            -b 4096 -ub 2048
            -fa 1 -lv 4
            --kv-unified
            --split-mode none --main-gpu 0
            -np 2 
            --temp 1.0 --top-p 0.95 --top-k 64
            --dry-penalty-last-n 0.05 --load-mode dio
            --spec-default
            -cram 16384

        "Flash": 
          env:    
            - "OCL_ICD_VENDORS=/run/opengl-driver/etc/OpenCL/vendors"
            - "ONEAPI_DEVICE_SELECTOR=level_zero:0"
            - "GGML_SYCL_SPARSE_FA=1"
            - "ZES_ENABLE_SYSMAN=1"
          cmd: | 
            ${llama-cpp}/bin/llama-server 
            -hf SC117/Qwen3.8-Flash-Next-GSQ-RCO-abliterated-GGUF:Q2_0
            --port ''${PORT}
            --ctx-size 128000 
            --no-mmproj
            -ctk q4_0 -ctv q4_0
            -ctkd q4_0 -ctvd q4_0
            -fa 1 -lv 4
            -b 4096 -ub 4096
            --kv-unified
            --moe-cache-mib 6000
            --spec-default
            -np 8
            -lm mmap 
            -lzm on

      healthCheckTimeout: 600  # 10 minutes for large model download + loading

      # TTL keeps models in memory for specified seconds after last use
      globalTTL: 1200  # Keep models loaded for 1 hour (like OLLAMA_KEEP_ALIVE)

      # Groups allow running multiple models simultaneously
      groups:
        embedding:
          # Keep embedding model always loaded alongside any other model
          persistent: true  # Prevents other groups from unloading this
          swap: false       # Don't swap models within this group
          exclusive: false  # Don't unload other groups when loading this
          members:
              - "embeddinggemma:300m"
              - "Reranker"
              - "Qwen:0.8B"
    '';

    # LLM oflload
    # all MOE -ot ".ffn_.*_exps.=CPU"
    # updown -ot ".ffn_(up|down)_exps.=CPU"
    # up-ot ".ffn_(up)_exps.=CPU"

    # Configure llama-swap as a systemd service
    systemd.services.llama-swap = {
      description = "llama-swap - OpenAI compatible proxy with automatic model swapping";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "admin";
        Group = "users";
        # Point to your declarative config file
        ExecStart = "${llama-swap}/bin/llama-swap --config /etc/llama-swap/config.yaml --listen 0.0.0.0:9292 --watch-config";
        Restart = "always";
        RestartSec = 10;

        # Environment for CUDA support
        Environment = [
          "PATH=/run/current-system/sw/bin"
          "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
        ];
      };
    };
  };
}
