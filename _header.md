# Azure Verified Module for Subscription Service Health Alerts

This pattern module deploys Azure Service Health alerting for a subscription. It creates activity log alerts, scoped to the subscription, that fire on:

| `service_health_alert` | Activity log category | Matches |
| --- | --- | --- |
| `Service Health Incident` | `ServiceHealth` | Service issues (incident type `Incident`) |
| `Service Health Maintenance` | `ServiceHealth` | Planned maintenance (incident type `Maintenance`) |
| `Service Health Advisory` | `ServiceHealth` | Health advisories (incident type `ActionRequired`) |
| `Service Health Security` | `ServiceHealth` | Security advisories (incident type `Security`) |
| `Resource Health Unhealthy` | `ResourceHealth` | Platform- or user-initiated `Degraded` or `Unavailable` resource health events |

By default, one alert of each type is created. Each alert can notify an action group that the module creates, with any of the supported receiver types, or an existing action group supplied by resource ID.

The alerts and action groups are placed in a resource group. By default the module creates a resource group named `rg-asha-<subscription ID>` in `location`; set `resource_group_creation_enabled = false` to use an existing resource group instead. Activity log alerts and action groups are global resources, so `location` only determines the resource group region and the telemetry region.

The module is implemented with the `Azure/azapi` provider and behaves like the Bicep pattern module [`avm/ptn/subscription/service-health-alerts`](https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/subscription/service-health-alerts).

## Required permissions

The identity running Terraform needs, on the target subscription:

- `Microsoft.Resources/subscriptions/resourceGroups/write` when the module creates the resource group.
- `Microsoft.Insights/activityLogAlerts/*` and `Microsoft.Insights/actionGroups/*` on the resource group, for example through the Monitoring Contributor or Contributor role.
- `Microsoft.Authorization/locks/*` when `lock` is set, for example through the Owner or User Access Administrator role.

## Notes

- Webhook service URIs, Logic App callback URLs, Azure Function trigger URLs and Automation webhook URIs usually contain secrets. Supply them through the sensitive `service_health_alert_receiver_secrets` variable, keyed by alert key and receiver name, not in `service_health_alerts`. The module sends them through the write-only `sensitive_body` argument of the AzAPI provider, so they are not shown in plan output or stored in Terraform state. The provider keeps only a hash of them in private state to detect changes. Saved plan files still contain input variable values, so protect them accordingly.
- Supplying `service_health_alert_receiver_secrets` requires Terraform 1.11 or later, because `sensitive_body` is a write-only argument. Without secret receivers, the module supports Terraform 1.9 or later.
- When `lock` is set, the module locks every alert and every action group it creates, and the resource group when the module creates it. An existing resource group is not locked.
