variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  description = "Kubernetes API endpoint, e.g. https://<control plane ip>:6443."
  type        = string
}

variable "talos_version" {
  description = "Talos version the configuration is rendered for, e.g. v1.14.2."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version the kubelet image is derived from. Keep it equal to the running nodes."
  type        = string
}

variable "machine_secrets_file" {
  description = "Path to the Talos secrets bundle (`talosctl gen secrets --from-controlplane-config`). Never commit it."
  type        = string
}

variable "gateway" {
  description = "Default gateway of every node."
  type        = string
}

variable "nameservers" {
  type = list(string)
}

variable "nodes" {
  description = "Worker nodes by hostname."
  type = map(object({
    ip             = string
    iface          = string
    disk           = string
    installer      = string
    labels         = optional(map(string))
    kernel_modules = optional(list(string))
    sysctls        = optional(map(string))
  }))
}

variable "control_plane" {
  description = "The (single) control plane node."
  type = object({
    name       = string
    ip         = string
    iface      = string
    disk       = string
    installer  = string
    labels     = map(string)
    extra_disk = optional(string)
  })
}

variable "cilium_cni" {
  description = "Cilium is the CNI and replaces kube-proxy: turns kube-proxy and the Talos-managed flannel off."
  type        = bool
  default     = false
}

variable "pod_subnets" {
  type    = list(string)
  default = ["10.244.0.0/16"]
}

variable "service_subnets" {
  type    = list(string)
  default = ["10.96.0.0/12"]
}

variable "dns_domain" {
  type    = string
  default = "cluster.local"
}

variable "google_client_id" {
  description = "Client id of a Google OAuth client; adds https://accounts.google.com as an apiserver JWT issuer with this audience. Empty disables it. An identifier, not a secret."
  type        = string
  default     = ""
}

variable "google_workspace_domain" {
  description = "Only accounts of this Google Workspace domain are accepted (the `hd` claim). Required when google_client_id is set."
  type        = string
  default     = ""

  validation {
    condition     = var.google_client_id == "" || var.google_workspace_domain != ""
    error_message = "google_workspace_domain is required when google_client_id is set."
  }
}
