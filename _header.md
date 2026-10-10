# Azure Verified Module for Subscription Service Health Alerts

This pattern module deploys Azure Service Health alerting for a subscription. It creates activity log alerts, scoped to the subscription, that fire on:

| `service_health_alert` | Activity log category | Matches |
| --- | --- | --- |
| `Service Health Incident` | `ServiceHealth` | Service issues (incident type `Incident`) |
| `Service Health Maintenance` | `ServiceHealth` | Planned maintenance (incident type `Maintenance`) |
| `Service Health Advisory` | `ServiceHealth` | Health advisories (incident type `ActionRequired`) |
| `Service Health Security` | `ServiceHealth` | Security advisories (incident type `Security`) |
| `Resource Health Unhealthy` | `ResourceHealth` | Platform- or user-initiated `Degraded` or `Unavailable` resource health events |

By default, one alert of each type is created, without notifications.

The alerts and action groups are placed in a resource group. By default the module creates `rg-asha-<subscription ID>` in `location`. Set `resource_group_creation_enabled = false` to use an existing resource group. Activity log alerts and action groups are global resources, so `location` only sets the resource group region and the telemetry region.

The module uses the `Azure/azapi` provider and behaves like the Bicep pattern module [`avm/ptn/subscription/service-health-alerts`](https://github.com/Azure/bicep-registry-modules/tree/main/avm/ptn/subscription/service-health-alerts).

## Notifications

An alert notifies action groups. Each receiver type (`email_receivers`, `sms_receivers`, `webhook_receivers` and so on) is a list, so one action group can notify several recipients. The options below can be combined on the same alert.

Shared action group, created once and notified by every alert, or by the alerts listed in `service_health_alert_keys`:

```hcl
shared_action_groups = {
  ops = {
    email_receivers = [
      { name = "ops", email_address = "ops@contoso.com" },
      { name = "oncall", email_address = "oncall@contoso.com" },
    ]
    sms_receivers = [
      { name = "oncall-sms", country_code = "33", phone_number = "612345678" },
    ]
  }
}
```

Action group dedicated to one alert:

```hcl
service_health_alerts = {
  incident = {
    service_health_alert = "Service Health Incident"
    action_group = {
      email_receivers = [{ name = "incident", email_address = "incident@contoso.com" }]
    }
  }
}
```

Existing action group:

```hcl
action_group = {
  existing_action_group = {
    resource_id = "/subscriptions/<subscription ID>/resourceGroups/<resource group>/providers/Microsoft.Insights/actionGroups/<name>"
  }
}
```

Action groups have no Microsoft Teams receiver. To post to Teams, use a `logic_app_receivers` entry pointing to a Logic App that sends the message.

### Receiver secrets

Webhook service URIs, Logic App callback URLs, Azure Function trigger URLs and Automation webhook URIs usually contain secrets. Supply them in `service_health_alert_receiver_secrets` or `shared_action_group_receiver_secrets`, keyed by the alert or shared action group key and then by receiver name:

```hcl
shared_action_group_receiver_secrets = {
  ops = {
    logic_app_receiver_callback_urls = {
      teams = var.teams_logic_app_callback_url
    }
  }
}
```

These values are sent through the write-only `sensitive_body` argument of the AzAPI provider. They are not shown in plan output or stored in state; the provider keeps only a hash of them to detect changes. Saved plan files still contain input variable values. Supplying receiver secrets requires Terraform 1.11 or later.

## Required permissions

On the target subscription:

- `Microsoft.Resources/subscriptions/resourceGroups/write` when the module creates the resource group.
- `Microsoft.Insights/activityLogAlerts/*` and `Microsoft.Insights/actionGroups/*`, for example through the Monitoring Contributor or Contributor role.
- `Microsoft.Authorization/locks/*` when `lock` is set, for example through the Owner or User Access Administrator role.

## Locks

When `lock` is set, the module locks every alert and action group it creates, and the resource group when it creates it. An existing resource group or action group is not locked.
