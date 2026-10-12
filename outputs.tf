output "action_group_resource_ids" {
  description = "A map of the resource IDs of the action groups created by this module, keyed by the `service_health_alerts` map key. Alerts that use an existing action group or no action group are not included."
  value       = { for key, config in local.action_group_configs : config.key => module.action_group[key].resource_id if config.scope == "alert" }
}

output "service_health_alert_resource_ids" {
  description = "A map of the resource IDs of the service health activity log alerts, keyed by the `service_health_alerts` map key."
  value       = { for key, alert in module.service_health_alert : key => alert.resource_id }
}

output "shared_action_group_resource_ids" {
  description = "A map of the resource IDs of the shared action groups, keyed by the `shared_action_groups` map key."
  value       = { for key, config in local.action_group_configs : config.key => module.action_group[key].resource_id if config.scope == "shared" }
}
