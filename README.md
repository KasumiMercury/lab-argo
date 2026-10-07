# lab-argo

Argo CD configuration for the Talos cluster built by [lab-proxmox](https://github.com/KasumiMercury/lab-proxmox).
lab-proxmox bootstraps the cluster, Cilium and Argo CD; from then on everything is managed from this repository.

## Layout
- `bootstrap/root.yaml`: root Application (app-of-apps). Applied once by hand
- `apps/`: Helm chart that renders one Application per component (`values.yaml` lists them with namespace, release name, sync wave)
- `platform/<component>/`: umbrella Helm chart per component. `Chart.yaml` + `Chart.lock` pin the upstream chart, `values.yaml` configures it under the dependency name, `templates/` holds extra manifests (SealedSecrets)
- `cilium/`: git submodule of [lab-cilium](https://github.com/KasumiMercury/lab-cilium), the Cilium chart pin (`version.yaml`) and values shared with the lab-proxmox bootstrap; see `cilium/README.md`. `apps/cilium` is a symlink to it so the app-of-apps chart can read the pin. Clone with `git clone --recurse-submodules` (or run `git submodule update --init`)

| Application | Chart | Namespace | Wave |
|---|---|---|---|
| gateway-api | Gateway API CRDs v1.6.1 (from `cilium/gateway-api.yaml`) | (cluster) | -4 |
| cilium | cilium 1.20.1 (from `cilium/version.yaml`) | kube-system | -3 |
| argocd | argo-cd 10.8.1 (Argo CD v3.5.2) | argocd | -2 |
| sealed-secrets | sealed-secrets 2.20.0 | kube-system | -1 |
| snapshot-controller | snapshot-controller 5.3.0 (piraeus; external-snapshotter v8.6.0 CRDs and controller) | kube-system | -2 |
| csi-driver-nfs | csi-driver-nfs 4.13.4 + StorageClass `nfs-csi`, VolumeSnapshotClass `nfs-csi` | kube-system | -1 |
| tailscale | tailscale-operator 1.102.4 | tailscale | 0 |
| kube-prometheus-stack | kube-prometheus-stack 91.9.0; Alertmanager sends the Loki ruler alerts and every warning/critical Prometheus alert to Slack #k8s-alert | monitoring | 1 |
| loki | loki 18.13.7 (Loki 3.7.8, grafana-community; monolithic, filesystem on a 10Gi `ceph-rbd` volume, 14-day retention), Grafana datasource `Loki`, dashboard `Logs overview`, ruler alerts on error spikes of the Kubernetes components and Cilium (`rules/k8s-alerts.yaml`) | logging | 1 |
| alloy | alloy 1.13.0 (Alloy v1.20.0; one replica reading Pod logs through the API and Kubernetes events, job `kubernetes-events`; drops recurring lines that never need action) | logging | 2 |
| alloy-talos | alloy 1.13.0 (hostNetwork DaemonSet receiving the Talos service and kernel logs on 127.0.0.1:6050/6051, `namespace="talos"`, `container=<service>`) | logging | 2 |
| public-gateway | Gateway `public` (Cilium), LB IPAM pool, cloudflared 2026.9.3 | public-gateway | 0 |
| external-dns | external-dns 1.23.0 (Cloudflare, mercuryksm.net) | external-dns | 1 |
| ceph-csi-rbd | ceph-csi-rbd 3.18.1 + StorageClass `ceph-rbd` (default; Proxmox Ceph, pool `k8s`, Retain), VolumeSnapshotClass `ceph-rbd` | ceph-csi-rbd | 0 |
| coredns | PodDisruptionBudget (`minAvailable: 1`) for the CoreDNS installed by Talos; its spread across nodes is set by the lab-proxmox bootstrap | kube-system | 0 |
| cilium-monitoring | PodMonitors for the Cilium agent, operator, Envoy and Hubble (dashboards come with the cilium chart), HTTP visibility policies (`l7Visibility`) | kube-system | 2 |
| obsidian-livesync | CouchDB 3.5.2 for Obsidian Self-hosted LiveSync, `talaria.mercuryksm.net` | obsidian-livesync | 2 |
| vaultwarden | Vaultwarden 1.37.4 (SQLite on a 2Gi `ceph-rbd` volume), tailnet only at `https://vault.<tailnet>.ts.net`; daily backup to the NAS (`vaultwarden-backup` on `/nfs/k8s`, 30 days) | vaultwarden | 2 |

- `argocd` and `cilium` have no resources finalizer: deleting their Application leaves Argo CD and the CNI running
- `argocd` adopts the release installed by the lab-proxmox bootstrap, so its chart version must match `version` in lab-proxmox `kubernetes/argocd.yaml`
- The Argo CD UI/API is on the tailnet at `https://argocd.<tailnet>.ts.net` (`platform/argocd/templates/server-ingress.yaml`). The Tailscale proxy terminates TLS, so argocd-server runs with `server.insecure` (also set in the lab-proxmox bootstrap values). CLI: `argocd login argocd.<tailnet>.ts.net --grpc-web`
- Argo CD reports Application health (custom health check in `platform/argocd/values.yaml`), so later waves wait for earlier ones

## Bootstrap
1. Build the cluster with lab-proxmox (`task tf:apply TF_ENV=k8s` and `task k8s:bootstrap TF_ENV=k8s`). The kubeconfig lands in `../lab-proxmox/ansible/artifacts/k8s.kubeconfig`, which the Taskfile uses by default (override with `KUBECONFIG=...`)
2. `task bootstrap` (applies `bootstrap/root.yaml` to the cluster in `KUBECONFIG`)
3. Once `sealed-secrets` is healthy, seal the credentials with the new cluster's key, commit and push:
   - `task seal:tailscale` → `platform/tailscale/templates/operator-oauth.sealedsecret.yaml` (OAuth client with the scopes and tag `tag:k8s-operator` described in the Tailscale operator docs)
   - `task seal:grafana` → `platform/kube-prometheus-stack/templates/grafana-admin.sealedsecret.yaml`
   - `task seal:slack` → `platform/kube-prometheus-stack/templates/alertmanager-slack.sealedsecret.yaml` (bot token of the Slack App shared with lab-proxmox, `vault_slack_bot_token`; the bot must be invited to #k8s-alert)

   Until then the Tailscale operator, Grafana and Alertmanager pods wait for their Secrets
4. To publish services on the internet (see [Publishing a service](#publishing-a-service)):
   - Create a tunnel dedicated to this cluster: `cloudflared tunnel login` and `cloudflared tunnel create <name>` (writes `~/.cloudflared/<tunnel-id>.json`). Do not route DNS to it by hand; external-dns does that
   - `task seal:cloudflared` → `platform/public-gateway/templates/cloudflared-credentials.sealedsecret.yaml`, and sets `tunnelID` in `platform/public-gateway/values.yaml`
   - `task seal:external-dns` → `platform/external-dns/templates/cloudflare-api-token.sealedsecret.yaml` (API token with Zone:Zone:Read and Zone:DNS:Edit on mercuryksm.net)
   - Commit and push. cloudflared is deployed and the Gateway gets the tunnel as its DNS target only once `tunnelID` is set
5. Ceph RBD volumes (`ceph-rbd`): on a Proxmox host create the pool and the client once (commands in `platform/ceph-csi-rbd/values.yaml`), then `task seal:ceph-csi` (`CEPH_USER_KEY=$(ssh root@<host> ceph auth get-key client.k8s)`). The k8s nodes must reach the mons and OSDs (192.168.20.0/24, TCP 3300/6789/6800-7300)
6. `task seal:couchdb` → `platform/obsidian-livesync/templates/couchdb-admin.sealedsecret.yaml` (CouchDB admin for LiveSync)
7. Vaultwarden (see [Vaultwarden](#vaultwarden)):
   - In the tailnet policy, let the operator own `tag:vaultwarden` (`"tag:vaultwarden": ["tag:k8s-operator"]` in `tagOwners`) and grant `tcp:443` on it to the users who need the vault only
   - `docker run --rm -it vaultwarden/server /vaultwarden hash --preset owasp`, then `task seal:vaultwarden` with the printed `ADMIN_TOKEN` → `platform/vaultwarden/templates/admin-token.sealedsecret.yaml`. Until then `/admin` is disabled

## Reproducing what Argo CD renders
Tools are pinned in `mise.toml` (`mise install`).
- `task render APP=<component>`: `helm template` of a component with the same release name and namespace as its Application
- `task render:cilium`: Cilium with the pin and values from `cilium/`
- `task render:apps`: the Applications generated by the root app
- `task lint`: lint and render everything (run before pushing)

## Upgrading a component
1. Change the dependency `version` in `platform/<component>/Chart.yaml`
2. `task deps:update APP=<component>` to rewrite `Chart.lock`
3. `task render APP=<component>` to review the result, then commit

Cilium is changed in lab-cilium (bump `version.yaml` one minor version at a time, see `cilium/README.md`). Push it there, then move the pointer here: `git submodule update --remote cilium` and commit `cilium`.

## Publishing a service
Services are published on the internet through the Gateway `public` (namespace `public-gateway`): Cloudflare terminates TLS, the tunnel (cloudflared) forwards every hostname to the Gateway over HTTP, and the Gateway picks the HTTPRoute by hostname.

1. If the service needs authentication, create its Cloudflare Access application for the hostname first. Nothing enforces this: a hostname without an Access application is public as soon as its record exists
2. Add an HTTPRoute next to the service:
   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   metadata:
     name: foo
     namespace: foo
   spec:
     parentRefs:
       - name: public
         namespace: public-gateway
     hostnames:
       - foo.mercuryksm.net
     rules:
       - backendRefs:
           - name: foo
             port: 80
   ```
3. external-dns creates the proxied CNAME `foo.mercuryksm.net` → `<tunnel-id>.cfargotunnel.com` plus its TXT ownership record, and deletes them with the HTTPRoute

external-dns only touches records that carry its TXT ownership entry (owner `lab-k8s`), so subdomains served by other tunnels are never changed; an HTTPRoute for a name that already exists is skipped (see the external-dns logs). It manages CNAME records only. Pick hostnames directly under `mercuryksm.net`: the free Universal SSL certificate does not cover deeper levels.

## Storage
`ceph-rbd` provisions RBD images in the Proxmox Ceph pool `k8s` through the Ceph user `client.k8s`, which can only use that pool. Its reclaim policy is Retain: deleting a PVC keeps the image (`rbd -p k8s ls` on a Proxmox host, remove it by hand).

`nfs-csi` provisions volumes on the NAS export `192.168.110.5:/nfs/k8s`, each in `<namespace>-<pvc>-<pv>`.
The export must allow the k8s VMs (`192.168.110.0/24`) and let root create directories (`no_root_squash`).
The Proxmox storage `strix0` (`/nfs/proxmox`) is a different export, reachable from the Proxmox hosts (`192.168.20.0/24`) only.
Prometheus keeps its TSDB there (20Gi, 15 days).

## Vaultwarden
`https://vault.<tailnet>.ts.net` is served by a Tailscale Ingress without Funnel, so only tailnet devices that the policy grants reach it; there is no HTTPRoute on the public Gateway. Clients (browser extension, mobile app) need Tailscale connected to sync; the offline cache keeps the vault readable.

- Signups are closed. Invite an address from `/admin` (Users → Invite); without SMTP the invited address can register directly
- No SMTP and no mobile push (the apps sync on open and periodically)
- Backup: the CronJob `vaultwarden-backup` runs at 03:30 JST next to the Vaultwarden Pod (the RBD volume is ReadWriteOnce), takes a consistent SQLite copy with `vaultwarden backup` and writes `vaultwarden-<UTC time>.tar.gz` (db.sqlite3, attachments, sends, RSA key) to `192.168.110.5:/nfs/k8s/vaultwarden-backup`, deleting archives older than 30 days. The PV is static with Retain, so the archives outlive the PVC and the Application. A failed run fires KubeJobFailed. Run one now: `kubectl -n vaultwarden create job --from=cronjob/vaultwarden-backup backup-manual`
- Restore: scale the StatefulSet to 0, extract the archive into the data volume (remove `db.sqlite3-wal` and `db.sqlite3-shm` first), `chown -R 1000:1000`, scale back to 1

## Secrets
- Only SealedSecrets are committed (`*.sealedsecret.yaml`); plaintext `*secret.yaml` files are gitignored
- The `seal:*` tasks build the Secret in memory from environment variables or a prompt and pipe it to `kubeseal`, so plaintext never touches the disk
- SealedSecrets can only be decrypted by the cluster that sealed them. Rebuilding the cluster means sealing again, or restoring the controller key: export it from the old cluster (`kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml`) and pass the file to the lab-proxmox bootstrap (`task k8s:bootstrap TF_ENV=k8s SEALED_SECRETS_KEY=<file>`), which applies it before the controller starts
