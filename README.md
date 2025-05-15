# NixOS K8S, N masters, N nodes, Stacked ETCD
If those things mean anything to you, you already know what this repo does. It
is an infrastructure as code (IaC) project focussed on achieving an easy way to
deploy Nix based Kubernetes nodes. The current NixOS k8s module is quite limited
when it comes to setting up more than one master [check the
wiki](https://nixos.wiki/wiki/Kubernetes). However, for high availability
(HA) this is preferred. The goal of this repo is to make that possible and easy.

## Another NixOS k8s HA repo??
yes.
There are other projects that work on the same issue:

1. [nix-infra-ha-cluster](https://github.com/jhsware/nix-infra-ha-cluster)
2. [nixos-ha-kubernetes](https://github.com/justinas/nixos-ha-kubernetes)

Citing mostly the same issues, HA support. The main difference is that this
effort targets bare metal deployments with [NixOS
anywhere](https://github.com/nix-community/nixos-anywhere) where the other
projects either deploy to the cloud or use terraform to deploy VM's locally.

# Cluster structure
``Machines.nix`` governs the structure of the cluster, everything is defined in
that toplevel file, from there everything is auto generated. Per node you can
change the IP, and what service is deployed to it, either kubernetes or etcd, or
both. When deploying it checks: is it a node? If it isn't you can't deploy to it, 
this is used for the Router, 
which in this repo does not run NixOS (if you have a NixOS router, you could
probably do a better job at this than me).
The basic deployment: 3 nodes, 3 kubernetes control planes, 3 etcd nodes. This
is a reasonable setup for HA.
In ``Machines.nix`` you can change settings for kubeMaster, this set governs
settings that apply to the load balancer and the IP that the control panel will
be exposed under, including the port. IP is the virtual IP that will be used by
the load balancer. Gateway is the Router speaking BGP. The load balancer used
here is [kube-vip](https://kube-vip.io/) deployed on each node as a static pod,
this is enabled with the option ``services.kubernetes.kubelet.manifests``, where
an attribute set describing the kube-vip manifest is used. The container is
deplyed using BGP mode, not ARP. Later I might add an option to switch between
these. Future work further entails auto generating this manifest, the current
manifest was generated on the command line, then yaml -> json -> nix, then the
derivation of the config transforms it back to json. (lol) 

# workflow

1. ``mkdir certs``
2. ``nix run .#apps.genCerts certs``
3. change ``machines.nix`` to your liking for your deployment
4. ``nix run .#apps.deploy <target>``

Target should be defined in ``machines.nix`` as the configuration and the deploy
script relies on this. Certs
have to be generated beforehand and can't be generated in the deployment step, as
all machines should have certs originating from the same source, otherwise they
can't talk to each other. 


