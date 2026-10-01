output "action_group_resource_ids" {
  description = "The resource IDs of the action groups created by the module."
  value       = module.test.action_group_resource_ids
}

output "service_health_alert_resource_ids" {
  description = "The resource IDs of the service health alerts."
  value       = module.test.service_health_alert_resource_ids
}
