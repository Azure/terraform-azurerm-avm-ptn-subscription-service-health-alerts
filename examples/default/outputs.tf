output "resource_group_resource_id" {
  description = "The resource ID of the resource group that holds the alerts."
  value       = module.test.resource_group_resource_id
}

output "service_health_alert_resource_ids" {
  description = "The resource IDs of the service health alerts."
  value       = module.test.service_health_alert_resource_ids
}
