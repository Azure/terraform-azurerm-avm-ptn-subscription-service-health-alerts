output "action_group_resource_ids" {
  description = "A map of the resource IDs of the action groups created by this module, keyed by the `service_health_alerts` map key. Alerts that use an existing action group or no action group are not included."
  value       = { for key, action_group in azapi_resource.action_group : key => action_group.id }
}

output "resource_group_resource_id" {
  description = "The resource ID of the resource group that holds the service health alerts and action groups."
  value       = local.resource_group_resource_id
}

output "service_health_alert_resource_ids" {
  description = "A map of the resource IDs of the service health activity log alerts, keyed by the `service_health_alerts` map key."
  value       = { for key, alert in azapi_resource.service_health_alert : key => alert.id }
}

output "shared_action_group_resource_ids" {
  description = "A map of the resource IDs of the shared action groups, keyed by the `shared_action_groups` map key."
  value       = { for key, action_group in azapi_resource.shared_action_group : key => action_group.id }
}
