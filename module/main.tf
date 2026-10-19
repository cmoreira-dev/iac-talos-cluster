# Talos machine configuration rendered from one node map. Render only: nothing here applies a
# configuration to a node (apply with `talosctl apply-config`, node by node, after a --dry-run).
#
# Talos 1.14 renders the multi-document format. The generator adds three defaults that old nodes
# lack and that change behaviour (SecurityProfileConfig, FilesystemTrimConfig, the EPHEMERAL
# VolumeConfig); `new_defaults_off` deletes them so a render of an existing cluster starts as a
# pure format migration.
locals {
  machine_secrets_raw = yamldecode(file(pathexpand(var.machine_secrets_file)))

  # secrets.yaml (talosctl) -> provider schema
  machine_secrets = {
    cluster = {
      id     = local.machine_secrets_raw.cluster.id
      secret = local.machine_secrets_raw.cluster.secret
    }
    secrets = {
      bootstrap_token             = local.machine_secrets_raw.secrets.bootstraptoken
      secretbox_encryption_secret = local.machine_secrets_raw.secrets.secretboxencryptionsecret
    }
    trustdinfo = {
      token = local.machine_secrets_raw.trustdinfo.token
    }
    certs = {
      etcd               = { cert = local.machine_secrets_raw.certs.etcd.crt, key = local.machine_secrets_raw.certs.etcd.key }
      k8s                = { cert = local.machine_secrets_raw.certs.k8s.crt, key = local.machine_secrets_raw.certs.k8s.key }
      k8s_aggregator     = { cert = local.machine_secrets_raw.certs.k8saggregator.crt, key = local.machine_secrets_raw.certs.k8saggregator.key }
      k8s_serviceaccount = { key = local.machine_secrets_raw.certs.k8sserviceaccount.key }
      os                 = { cert = local.machine_secrets_raw.certs.os.crt, key = local.machine_secrets_raw.certs.os.key }
    }
  }

  # New-in-1.14 defaults that the old nodes do not have and that change behaviour.
  new_defaults_off = join("---\n", [
    yamlencode({ apiVersion = "v1alpha1", kind = "SecurityProfileConfig", "$patch" = "delete" }),
    yamlencode({ apiVersion = "v1alpha1", kind = "FilesystemTrimConfig", "$patch" = "delete" }),
    yamlencode({ apiVersion = "v1alpha1", kind = "VolumeConfig", name = "EPHEMERAL", "$patch" = "delete" }),
  ])

  patches = {
    for name, n in var.nodes : name => [
      # v1alpha1: only what the new documents do not replace
      yamlencode({
        machine = merge(
          {
            network = {
              interfaces = [{
                interface = n.iface
                addresses = ["${n.ip}/24"]
                routes    = [{ network = "0.0.0.0/0", gateway = var.gateway }]
              }]
            }
          },
          try(n.kernel_modules, null) == null ? {} : { kernel = { modules = [for m in n.kernel_modules : { name = m }] } },
          try(n.sysctls, null) == null ? {} : { sysctls = n.sysctls },
        )
      }),
      yamlencode({
        apiVersion  = "v1alpha1"
        kind        = "ResolverConfig"
        nameservers = [for a in var.nameservers : { address = a }]
      }),
      yamlencode({
        apiVersion   = "v1alpha1"
        kind         = "UnattendedInstallConfig"
        installer    = { image = n.installer }
        provisioning = { diskSelector = { match = "disk.dev_path == \"${n.disk}\"" }, wipe = true }
      }),
      try(n.labels, null) == null ? "" : yamlencode({ apiVersion = "v1alpha1", kind = "KubeNodeConfig", labels = n.labels }),
      # hostname and `auto` are exclusive: drop the default document, add ours
      yamlencode({ apiVersion = "v1alpha1", kind = "HostnameConfig", "$patch" = "delete" }),
      yamlencode({ apiVersion = "v1alpha1", kind = "HostnameConfig", hostname = name }),
      local.new_defaults_off,
    ]
  }

  control_plane = var.control_plane

  control_plane_patches = [
    yamlencode({
      machine = {
        network = {
          interfaces = [{
            interface = local.control_plane.iface
            addresses = ["${local.control_plane.ip}/24"]
            routes    = [{ network = "0.0.0.0/0", gateway = var.gateway }]
          }]
        }
        disks = local.control_plane.extra_disk == null ? [] : [{ device = local.control_plane.extra_disk }]
      }
    }),
    yamlencode({
      apiVersion  = "v1alpha1"
      kind        = "ResolverConfig"
      nameservers = [for a in var.nameservers : { address = a }]
    }),
    yamlencode({
      apiVersion   = "v1alpha1"
      kind         = "UnattendedInstallConfig"
      installer    = { image = local.control_plane.installer }
      provisioning = { diskSelector = { match = "disk.dev_path == \"${local.control_plane.disk}\"" }, wipe = true }
    }),
    yamlencode({ apiVersion = "v1alpha1", kind = "KubeNodeConfig", labels = local.control_plane.labels }),
    # The legacy --oidc-* apiserver flags are rejected by the new KubeAPIServerConfig; same
    # semantics through the structured authentication config (no username/groups prefix, the
    # flag default for the `email` claim). `anonymous` keeps the Talos default so the
    # apiserver probes on /livez, /readyz and /healthz keep working.
    yamlencode({
      apiVersion = "v1alpha1"
      kind       = "KubeAuthenticationConfig"
      configuration = {
        anonymous = {
          enabled    = true
          conditions = [{ path = "/livez" }, { path = "/readyz" }, { path = "/healthz" }]
        }
        jwt = concat(
          # Google Workspace (ADR 0002), the only issuer; enabled when a client id is set.
          # Usernames are prefixed (`google:<user>@<domain>`) so they can never collide
          # with another issuer or a system:* user, and tokens must come from a verified
          # account of the Workspace domain. Google tokens carry no groups claim.
          var.google_client_id == "" ? [] : [{
            issuer = {
              url       = "https://accounts.google.com"
              audiences = [var.google_client_id]
            }
            claimMappings = {
              username = { claim = "email", prefix = "google:" }
            }
            claimValidationRules = [
              { expression = "claims.email_verified == true", message = "the email must be verified" },
              { expression = "claims.hd == '${var.google_workspace_domain}'", message = "only ${var.google_workspace_domain} accounts" },
            ]
          }],
        )
      }
    }),
    # With Cilium as the CNI, kube-proxy is off and there is no Talos-managed flannel.
    var.cilium_cni ? yamlencode({ apiVersion = "v1alpha1", kind = "KubeProxyConfig", enabled = false, config = {} }) : "",
    yamlencode({
      apiVersion     = "v1alpha1"
      kind           = "KubeNetworkConfig"
      dnsDomain      = var.dns_domain
      podSubnets     = var.pod_subnets
      serviceSubnets = var.service_subnets
    }),
    var.cilium_cni ? yamlencode({ apiVersion = "v1alpha1", kind = "KubeFlannelCNIConfig", "$patch" = "delete" }) : "",
    yamlencode({ apiVersion = "v1alpha1", kind = "HostnameConfig", "$patch" = "delete" }),
    yamlencode({ apiVersion = "v1alpha1", kind = "HostnameConfig", hostname = local.control_plane.name }),
    local.new_defaults_off,
  ]
}

data "talos_machine_configuration" "worker" {
  for_each = var.nodes

  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = local.machine_secrets
  talos_version    = var.talos_version
  # Equal to the running kubelet; the provider default may be older.
  kubernetes_version = var.kubernetes_version
  config_patches     = [for p in local.patches[each.key] : p if p != ""]
}

data "talos_machine_configuration" "controlplane" {
  cluster_name       = var.cluster_name
  cluster_endpoint   = var.cluster_endpoint
  machine_type       = "controlplane"
  machine_secrets    = local.machine_secrets
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  config_patches     = [for p in local.control_plane_patches : p if p != ""]
}
