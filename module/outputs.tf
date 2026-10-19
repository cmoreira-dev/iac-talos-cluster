output "machine_configuration" {
  description = "Rendered machine configuration per node (workers and control plane). Contains cluster secrets: sensitive, never print it."
  value = merge(
    { for k, d in data.talos_machine_configuration.worker : k => d.machine_configuration },
    { (local.control_plane.name) = data.talos_machine_configuration.controlplane.machine_configuration },
  )
  sensitive = true
}
