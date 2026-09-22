#steam_server
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.llm.enable;
  # last updated on 28th of june 2026
  llama-cpp = pkgs.llama-cpp-sycl.overrideAttrs (oldAttrs: rec {
    version = "11064";
    src = pkgs.fetchFromGitHub {
      owner = "ggml-org";
      repo = "llama.cpp";
      tag = "b${version}";
      hash = "sha256-Qsvu7HHKzbzXuu1eTZd3PEwIzwHsMs2vDLwSQXeQrwY=";
      # hash = "sha256-0000000000000000000000000000000000000000000=";

      leaveDotGit = true;
      postFetch = ''
        git -C "$out" rev-parse --short HEAD > $out/COMMIT
        find "$out" -name .git -print0 | xargs -0 rm -rf
      '';
    };
    npmDepsHash = "sha256-2Q7XhaLAArmviOLdQsNbYTfdyDE5pW9lR26cRHEVl9k=";
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
          cmd: | 
              ${llama-cpp}/bin/llama-server 
              -hf DavidAU/Qwen3.8-27B-TURBO-Fable-Cold-Fusion-735-882-Heretic-Uncensored-NEO-CODER-MAX-MTP-GGUF:Q4_K_M 
              --port ''${PORT} 
              --threads 18 --jinja --ctx-size 131072 -ngl 999 -ctk q8_0 --cache-type-v q8_0 -b 4096 -ub 2048 -fa 1 -lv 4 
              --no-mmproj --split-mode none --main-gpu 0 -np 2 --dry-penalty-last-n 0.05 --spec-type draft-mtp --spec-draft-n-max 3 --kv-unified --reasoning-preserve --load-mode dio 
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
          cmd: | 
            ${llama-cpp}/bin/llama-server 
            -hf unsloth/Muse-Glimmer-30B-GGUF:UD-Q4_K_XL
            --port ''${PORT}
            --threads 18 --jinja 
            --ctx-size 131072 -ngl 999 
            -b 4096 -ub 2048
            -fa 1 -lv 4
            --kv-unified
            --split-mode none --main-gpu 0
            -np 2 
            --temp 1.0 --top-p 0.95 --top-k 64
            --dry-penalty-last-n 0.05 --load-mode dio
            --spec-default
            # --spec-type draft-dflash --spec-draft-n-max 3
          filters:
            setParamsByID:
               "Muse:high":
                   chat_template_kwargs:
                     reasoning_effort: high
               "Muse:xhigh":
                   chat_template_kwargs:
                       reasoning_effort: xhigh
               "Muse":
                   chat_template_kwargs:
                      reasoning_effort: medium
               "Muse:low":
                   chat_template_kwargs:
                      reasoning_effort: low

        # ADDED 20-09-2026
        "Goetia": 
          env:    
            - "OCL_ICD_VENDORS=/run/opengl-driver/etc/OpenCL/vendors"
          cmd: | 
            ${llama-cpp}/bin/llama-server 
            -hf mradermacher/Goetia-26B-A4B-v1.6-i1-GGUF:Q4_K_M
            --port ''${PORT}
            --threads 18 --jinja 
            --ctx-size 131072 -ngl 999 
            -b 4096 -ub 2048
            -fa 1 -lv 4
            --kv-unified
            --split-mode none --main-gpu 0
            -np 2 
            --temp 1.0 --top-p 0.95 --top-k 64
            --dry-penalty-last-n 0.05 --load-mode dio
            --spec-default

        "Split": 
          env:    
            - "OCL_ICD_VENDORS=/run/opengl-driver/etc/OpenCL/vendors"
          cmd: | 
            ${llama-cpp}/bin/llama-server 
            -hf mradermacher/Split-Untied-31B-i1-GGUF:Q4_K_S
            --port ''${PORT}
            --threads 18 --jinja 
            --ctx-size 64000 -ngl 999 
            -b 4096 -ub 2048
            -fa 1 -lv 4
            --kv-unified
            --split-mode none --main-gpu 0
            -np 2 
            --temp 1.0 --top-p 0.95 --top-k 64
            --dry-penalty-last-n 0.05 --load-mode dio
            --spec-default

        #-hf DavidAU/Qwen3.6-27B-Fable-Fusion-711-Uncensored-Heretic-NM-DAU-NEO-MAX-MTP-GGUF:Q4_K_M
        # --spec-draft-ngl all

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
