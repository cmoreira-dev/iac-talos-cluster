# iac-talos-cluster

Talos machine configuration rendered from one node map. The module declares only `data` sources, so a
plan never changes a node; it shows whether the rendered configuration still equals the last one.

## Inputs (`module/variables.tf`)

| Variable | Purpose |
|---|---|
| `cluster_name`, `cluster_endpoint`, `talos_version`, `kubernetes_version` | Cluster identity and versions (keep `kubernetes_version` equal to the running nodes) |
| `machine_secrets_file` | Talos secrets bundle (`talosctl gen secrets --from-controlplane-config`). Never commit it |
| `gateway`, `nameservers` | Network of every node (the module assumes a /24) |
| `nodes` | Workers by hostname: `ip`, `iface`, `disk`, `installer`, optional `labels`, `kernel_modules`, `sysctls` |
| `control_plane` | The single control plane node |
| `cilium_cni` | Turns kube-proxy and the Talos-managed flannel off |
| `pod_subnets`, `service_subnets`, `dns_domain` | Talos defaults unless set |
| `google_client_id`, `google_workspace_domain` | Optional: Google as an apiserver JWT issuer (claim `email` prefixed `google:`, `email_verified` and `hd` enforced) |

## Rollout (outside the module)

Render, then compare with `talosctl apply-config --dry-run` per node; apply node by node, workers
first and the control plane last. The module's job is only to make the render reproducible.

## Notes

- Talos 1.14 adds three defaults that change behaviour on old nodes (`SecurityProfileConfig`,
  `FilesystemTrimConfig`, the `EPHEMERAL` `VolumeConfig`); the module deletes them.
- The legacy `--oidc-*` apiserver flags are rejected by the new `KubeAPIServerConfig`; OIDC goes through
  `KubeAuthenticationConfig` (structured authentication config). The `anonymous` health paths are kept
  so the apiserver probes keep working.
- The secrets bundle goes into the rendered output (sensitive). Never print it.
