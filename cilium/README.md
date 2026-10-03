# cilium

Cilium configuration for the MicroK8s cluster built by `lab-proxmox`.
This directory is meant to become a git submodule shared with the ArgoCD repository, so it must stay
self-contained: no references to files outside this directory.

## Files
- `version.yaml`: Helm repo, chart name and chart version (the single pin)
- `values.yaml`: Helm values. Contains the MicroK8s-specific paths and the pod CIDR; anything else
  (custom images, features) is added here and rolled out by ArgoCD

## Who reads it
- **Ansible (`lab-proxmox`)**: bootstrap only. On a fresh cluster it runs
  `microk8s helm3 install cilium <repo>/<chart> --version <version> --values values.yaml` so that ArgoCD
  has a network to run on. It never upgrades or reconfigures an existing installation.
- **ArgoCD (`lab-argo`)**: owns every change after bootstrap. This directory is checked out at `cilium/`;
  the app-of-apps chart reads `version.yaml` (through the `apps/cilium` symlink) to fill the chart pin and
  renders a multi-source Application with `releaseName: cilium` in `kube-system` and
  `$values/cilium/values.yaml`.

## Contract
- Keep `cni.confPath`, `cni.binPath` and `ipam.operator.clusterPoolIPv4PodCIDRList` as they are unless
  the MicroK8s side changes; the bootstrap depends on them.
- `kubeProxyReplacement: true` with `k8sServiceHost: 127.0.0.1` / `k8sServicePort: 16443` is part of the
  node contract: Ansible disables MicroK8s' kube-proxy on every node because this is true. Turning it off
  later requires Ansible to re-enable kube-proxy first (`kubeProxyReplacement` cannot be toggled on a
  running cluster without breaking existing connections).
- Bump `version.yaml` one minor version at a time (Cilium only supports consecutive-minor upgrades) and
  move the submodule pointer in the ArgoCD repo in the same change, so a freshly bootstrapped cluster
  and ArgoCD agree on the version.
- Deleting the ArgoCD Application must not delete Cilium: do not add the resources finalizer.
