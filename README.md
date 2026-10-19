# iac-talos-cluster

Reusable OpenTofu/Terraform module: renders the Talos machine configuration of a cluster (workers and
control plane) from one node map, with the `siderolabs/talos` provider. **Render only**: nothing
applies a configuration to a node.

Consumed through Terragrunt, one unit per cluster:

```hcl
terraform {
  source = "git::https://github.com/cmoreira-dev/iac-talos-cluster.git//module?ref=v0.1.0"
}

inputs = {
  cluster_name         = "<name>"
  cluster_endpoint     = "https://<control plane ip>:6443"
  talos_version        = "v1.14.2"
  kubernetes_version   = "<running kubernetes version>"
  machine_secrets_file = "<path to the secrets bundle>"
  gateway              = "<gateway>"
  nameservers          = ["<dns>"]
  nodes                = { "<hostname>" = { ip = "...", iface = "...", disk = "...", installer = "..." } }
  control_plane        = { name = "...", ip = "...", iface = "...", disk = "...", installer = "...", labels = {} }
}
```

See [docs/index.md](docs/index.md).
