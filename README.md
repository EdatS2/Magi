# Magi: NixOS K3s Infrastructure as Code

An IaC project for deploying highly available (HA) Kubernetes clusters using NixOS and `k3s`. This repository automates the provisioning of bare-metal nodes, providing a scalable and reproducible way to manage a production-grade cluster.

## Core Technologies

* **NixOS**: Fully reproducible system configuration.
* **K3s**: Lightweight Kubernetes distribution, managed via a single bootstrapper node.
* **HA Networking**: Load balancing and high availability managed via `keepalived` and `haproxy`.
* **sops-nix**: Secure, declarative secret management integrated into the Nix lifecycle.
* **Disko**: Declarative disk partitioning and formatting.
* **Helmfile**: Orchestrates the deployment of all services running within the cluster.

## Configuration (`machines.nix`)

The entire cluster topology is defined in `machines.nix`. Each node is a function of `pkgs` that can be used by other Nix modules.

### Node Attributes
* `ip`: IP address on the Kubernetes management network.
* `localIp`: IP address on the local management network (used for SSH and initial access).
* `interface`: Primary network interface for the node.
* `longhornInterface` & `longhornIP`: Dedicated network interface and IP for block storage traffic.
* `disk`: The root block device (e.g., `/dev/nvme0n1`).
* `master`: If `true`, this node is a control plane node. The first one defined acts as the k3s bootstrapper.
* `node`: If `true`, enables node-level components (e.g., docker, kubelet).
* `zfs`: Enables ZFS pools and object storage (Garage).

### Cluster-wide Settings (`kubeMaster`)
The `kubeMaster` block in `machines.nix` defines the Virtual IP (VIP) used by Keepalived and HAProxy:
```nix
  kubeMaster = {
    ip = "10.13.13.100"; # The VIP
    gateway = "10.13.13.1"; # BGP Gateway
    port = 6443; # API Server Port
    name = "kubernetes";
  };
```

## Secret Management (`sops-nix`)

The cluster uses `sops-nix` with the `age` backend for secure, declarative secret management. Unlike other IaC tools, secrets are injected into the Nix store and decrypted into a volatile RAM filesystem (`ramfs`) during the NixOS activation phase.

### 1. Identity Configuration
Secrets are configured to be decrypted using the node's own SSH host keys. In `configuration.nix`:
```nix
sops.age.sshKeyPaths = config.services.openssh.hostKeys;
```
This means every node has a unique identity, and a single encrypted file can be used across all nodes.

### 2. The Workflow
1. **Create/Update Secrets**: Create a file in the `secrets/` directory (e.g., `secrets/garage.yaml`).
2. **Encrypt**: Use `sops` to encrypt the file. The public identity is derived from your Nix configuration.
3. **Reference in Nix**: Point your service configuration to the decrypted path provided by `sops`:
   ```nix
   services.garage.settings.admin.admin_token_file = config.sops.secrets.garage_admin_token.path;
   ```

### 3. Bootstrap & Provisioning
During the initial `deploy.nix` (or `nixos-anywhere`) phase, the necessary **private** identities are injected securely into the node's filesystem (e.g., into `/etc/secrets/`). Once deployed, `sops-nix` handles the decryption automatically during the NixOS activation phase, ensuring secrets never touch the disk.

## Workflow

### 1. Provisioning a New Node
To deploy a new node to your cluster:
1. **Define the Machine**: Add the node's configuration to `machines.nix`.
2. **Deploy**:
   ```bash
   nix run .#apps.deploy <machine_name>
   ```
   *The `deploy` app uses `nixos-anywhere` to bootstrap the node, passing all necessary certificates and secrets via the `--extra-files` flag.*

### 2. Cluster Maintenance

* **Update Configuration**:
  ```bash
  nix run .#apps.update <machine_name>
  ```
* **Manage Services**: All cluster-side applications (like Nextcloud, Immich, etc.) are managed and updated via `helmfile`.
  ```bash
  # Example (run from the repo root)
  helmfile sync
  ```

---
*Note: This repository is designed for bare-metal deployments. Ensure your local environment is configured to manage `sops-nix` secrets via the appropriate `age` identities.*
