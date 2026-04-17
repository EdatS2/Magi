#steam_server
{ lib, pkgs, config, ... }:
let 
    cfg = config.llm.enable;
# last updated on 11th of March 2026
    llama-cpp =
      (pkgs.llama-cpp.override {
        cudaSupport = true;
        rocmSupport = false;
        metalSupport = false;
        # Enable BLAS for optimized CPU layer performance (OpenBLAS)
        blasSupport = true;
      }).overrideAttrs
        (oldAttrs: rec {
          version = "8637";
          src = pkgs.fetchFromGitHub {
            owner = "ggml-org";
            repo = "llama.cpp";
            tag = "b${version}";
            hash = "sha256-H8LUjxmqiAmnFKCea4ZclorvznnGgnAgyIjVFLQJINE=";
            # hash = "sha256-0000000000000000000000000000000000000000000=";

            leaveDotGit = true;
            postFetch = ''
              git -C "$out" rev-parse --short HEAD > $out/COMMIT
              find "$out" -name .git -print0 | xargs -0 rm -rf
            '';
          };
          npmDepsHash = "sha256-DxgUDVr+kwtW55C4b89Pl+j3u2ILmACcQOvOBjKWAKQ=";
          # npmDepsHash = "sha256-0000000000000000000000000000000000000000000=";
          # Enable native CPU optimizations (AVX, AVX2, etc.)
          cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
            "-DGGML_NATIVE=ON"
            "-DGGML_CUDA_FA_ALL_QUANTS=ON"
            "-DCMAKE_CUDA_ARCHITECTURES=86"
          ];
          # Disable Nix's march=native stripping
          preConfigure = ''
            export NIX_ENFORCE_NO_NATIVE=0
            ${oldAttrs.preConfigure or ""}
          '';
          postPatch = '''';
        });
         # llama-swap from GitHub releases
        llama-swap = pkgs.runCommand "llama-swap" { } ''
          mkdir -p $out/bin
          tar -xzf ${
            pkgs.fetchurl {
              url =
              "https://github.com/mostlygeek/llama-swap/releases/download/v190/llama-swap_190_linux_amd64.tar.gz";
              hash = "sha256-WAfmJ4YiVH/UYq++l2Ut6oLqkd270HgG7eV+6FG/0Oc=";
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
              # Uploaded 2025-08-02, size 11.3 GB, max ctx: 131072, layers: 24
              "gpt-oss-medium:20b":
                cmd: |
                  ${llama-cpp}/bin/llama-server
                  -hf ggml-org/gpt-oss-20b-GGUF
                  --port ''${PORT}
                  --threads 18
                  --chat-template-kwargs '{"reasoning_effort": "high"}'
                  --jinja
                  --ctx-size 65536
                  --cache-type-k q8_0
                  --cache-type-v q4_1
                  --flash-attn on
                  --direct-io

              # Uploaded 2025-09-04, size 0.3 GB, max ctx: 2048, layers: 24
              "embeddinggemma:300m":
                cmd: |
                  ${llama-cpp}/bin/llama-server
                  -hf ggml-org/embeddinggemma-300M-GGUF
                  --port ''${PORT}
                  --embeddings
                  --batch-size 2048
                  --ubatch-size 2048
              # Updated 11-03-2026
              "Reranker":
                cmd: |
                  ${llama-cpp}/bin/llama-server
                  -hf ggml-org/Qwen3-Reranker-0.6B-Q8_0-GGUF:Q8_0
                  --port ''${PORT}
                  --batch-size 2048
                  --ubatch-size 2048
                  --reranking


              # Alternative model -hf unsloth/GLM-4.7-Flash-GGUF:Q4_K_M

              # ADDED 14-02-2026
              "GLM-4.7:30b":
                cmd: ${llama-cpp}/bin/llama-server -hf DavidAU/GLM-4.7-Flash-Uncensored-Heretic-NEO-CODE-Imatrix-MAX-GGUF:Q4_K_M --port ''${PORT} --threads 18 --jinja --min-p 0.01 --temp 1.0 --top-p 0.95 --ctx-size 65536 --cache-type-k q8_0 --cache-type-v q4_0 --flash-attn on --direct-io # --parallel 2

              # ADDED 19-02-2026
              "Cydonia:24B":
                cmd: ${llama-cpp}/bin/llama-server -hf bartowski/TheDrummer_Cydonia-24B-v4.3-GGUF:Q4_K_M --port ''${PORT} --threads 18 --jinja --min-p 0.01 --temp 1.0 --top-p 0.95 --ctx-size 16384 --cache-type-k q8_0 --cache-type-v q4_1 --flash-attn on --direct-io

              # ADDED 11-03-2026
              "Qwen:35B": 
                cmd: | 
                    ${llama-cpp}/bin/llama-server 
                    -hf unsloth/Qwen3.5-35B-A3B-GGUF:UD-Q3_K_XL --port ''${PORT}
                    --threads 18 --jinja --min-p 0.01 --temp 1.0 --top-p 0.95
                    --ctx-size 60000 --cache-type-k q8_0 --cache-type-v q4_1
                    --flash-attn on --direct-io --ctx-checkpoints 64
                    --checkpoint-every-n-tokens 2048 --fit-target 2048
            
              # ADDED 02-04-2026
              "Gemma:26B": 
                cmd: | 
                    ${llama-cpp}/bin/llama-server 
                    -hf unsloth/gemma-4-26B-A4B-it-GGUF:UD-Q3_K_XL --port ''${PORT}
                    --threads 18 --jinja --min-p 0.01 --temp 1.0 --top-p 0.95
                    --ctx-size 120000 --cache-type-k q8_0 --cache-type-v q8_0
                    --flash-attn on --direct-io --ctx-checkpoints 64
                    --checkpoint-every-n-tokens 2048 --fit-target 2048
                    --parallel 2 --reasoning-budget 1000


                    # -hfd Jackrong/Qwen3.5-0.8B-Claude-4.6-Opus-Reasoning-Distilled-GGUF:Q4_K_S 
                    # -ctkd q8_0 -ctvd q4_1 -cd 65536



            healthCheckTimeout: 600  # 10 minutes for large model download + loading

            # TTL keeps models in memory for specified seconds after last use
            ttl: 300  # Keep models loaded for 1 hour (like OLLAMA_KEEP_ALIVE)

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

              # ADDED 14-02-2026
#              "Kimi:48b":
#                cmd: |
#                  ${llama-cpp}/bin/llama-server
#                  -hf bartowski/moonshotai_Kimi-Linear-48B-A3B-Instruct-GGUF:Q4_K_M
#                  --port ''${PORT}
#                  --threads 18
#                  --jinja
#                  --min-p 0.01
#                  --temp 1.0 
#                  --top-p 0.95
#                  --ctx-size 32768
#                  --cache-type-k q8_0
#                  --cache-type-v q8_0
#                  --flash-attn on
#                  --direct-io
#


               # ADDED 19-02-2026
              # "Qwen:80B":
              #   cmd: |
              #     ${llama-cpp}/bin/llama-server
              #     -hf unsloth/Qwen3-Coder-Next-GGUF:UD-Q3_K_XL
              #     --port ''${PORT}
              #     --threads 18
              #     --jinja
              #     --min-p 0.01
              #     --temp 1.0 
              #     --top-p 0.95
              #     --ctx-size 65536
              #     --cache-type-k q8_0
              #     --cache-type-v q8_0
              #     --flash-attn on
              #     --direct-io
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

