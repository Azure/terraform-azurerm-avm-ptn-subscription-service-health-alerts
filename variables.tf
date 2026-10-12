variable "location" {
  type        = string
  description = "Azure region used for the resource group created by this module and for the module telemetry. Activity log alerts and action groups are always deployed to the `global` location."
  nullable    = false
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "ignore_body_changes" {
  type = object({
    authorization_locks          = optional(list(string), [])
    insights_action_groups       = optional(list(string), [])
    insights_activity_log_alerts = optional(list(string), [])
    resources_resource_groups    = optional(list(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
Paths in each resource's `body` whose changes the AzAPI provider ignores. Prefer Terraform's `lifecycle.ignore_changes` when the paths are static; use this variable when the paths must be derived from variables or other non-static values.

Paths use dot notation, for example `properties.enabled`. Individual list items cannot be targeted; ignore the whole list property instead. Configuration changes at an ignored path are **not** sent to Azure until that path is removed from the list.

Supplying a non-empty value requires Terraform 1.11 or later, because `ignore_body_changes` is a write-only argument. Changes take effect only after an apply, because the value is held in provider-private state.

- `authorization_locks` - Ignored body paths for the management locks created by this module.
- `insights_action_groups` - Ignored body paths for the action groups created by this module.
- `insights_activity_log_alerts` - Ignored body paths for the service health activity log alerts.
- `resources_resource_groups` - Ignored body paths for the resource group created by this module.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue(flatten([
      for paths in values(var.ignore_body_changes) : [
        for path in paths : trimspace(path) != ""
      ]
    ]))
    error_message = "Each `ignore_body_changes` path must be a non-empty string."
  }
}

variable "lock" {
  type = object({
    kind  = string
    name  = optional(string, null)
    notes = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
Controls the Resource Lock configuration for this resource. The following properties can be specified:

- `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
- `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
- `notes` - (Optional) Notes about the lock. This value maps to `Microsoft.Authorization/locks.properties.notes`.
DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "resource_group_creation_enabled" {
  type        = bool
  default     = true
  description = "Whether the module creates the resource group that holds the alerts and action groups. Set to `false` to deploy into an existing resource group named by `resource_group_name` in the target subscription."
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  default     = null
  description = "The name of the resource group that holds the service health alerts and action groups. When `null`, the name defaults to `rg-asha-<subscription ID>`."

  validation {
    condition     = var.resource_group_name == null || (can(regex("^[-\\w\\._\\(\\)]{1,90}$", var.resource_group_name)) && !endswith(var.resource_group_name, "."))
    error_message = "`resource_group_name` must be 1-90 characters, contain only alphanumerics, underscores, parentheses, hyphens and periods, and not end with a period."
  }
}

variable "resource_types" {
  type = object({
    authorization_locks          = optional(string, "Microsoft.Authorization/locks@2020-05-01")
    insights_action_groups       = optional(string, "Microsoft.Insights/actionGroups@2023-01-01")
    insights_activity_log_alerts = optional(string, "Microsoft.Insights/activityLogAlerts@2026-01-01")
    resources_resource_groups    = optional(string, "Microsoft.Resources/resourceGroups@2025-04-01")
  })
  default     = {}
  description = <<DESCRIPTION
Override the AzAPI `<provider>/<resource>@<api-version>` strings used by this module. Each key defaults to a tested value; supply only the keys you want to override. Useful when targeting a sovereign cloud with older API versions, or when opting into a newer preview API.

- `authorization_locks` - Management locks applied when `lock` is set.
- `insights_action_groups` - Action groups created for the alerts.
- `insights_activity_log_alerts` - Service health and resource health activity log alerts.
- `resources_resource_groups` - Resource group created when `resource_group_creation_enabled` is `true`.
DESCRIPTION
  nullable    = false
}

variable "retry" {
  type = object({
    error_message_regex  = optional(list(string))
    interval_seconds     = optional(number)
    max_interval_seconds = optional(number)
  })
  default     = null
  description = <<DESCRIPTION
Retry configuration applied to every `azapi` resource managed by the module. Defaults to `null` (no custom retry).

- `error_message_regex`  - (Optional) A list of regex patterns matching error messages that trigger a retry.
- `interval_seconds`     - (Optional) Initial interval between retries in seconds.
- `max_interval_seconds` - (Optional) Maximum interval between retries in seconds.

See <https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource#retry> for full semantics.
DESCRIPTION
}

variable "service_health_alert_receiver_secrets" {
  type = map(object({
    automation_runbook_receiver_service_uris  = optional(map(string), {})
    azure_function_receiver_http_trigger_urls = optional(map(string), {})
    logic_app_receiver_callback_urls          = optional(map(string), {})
    webhook_receiver_service_uris             = optional(map(string), {})
  }))
  default     = {}
  description = <<DESCRIPTION
Secret URLs for the receivers of the action groups created by this module. The outer map key must match the `service_health_alerts` key of an alert whose action group is created by this module. Each inner map is keyed by the receiver `name` in the corresponding receiver list.

The values are sent to Azure through the write-only `sensitive_body` argument of the AzAPI provider, so they are not shown in plan output and are not stored in Terraform state; only a hash of them is kept in provider-private state to detect changes. Supplying a non-empty value requires Terraform 1.11 or later.

- `automation_runbook_receiver_service_uris` - (Optional) The Automation webhook URI for each automation runbook receiver, keyed by receiver name.
- `azure_function_receiver_http_trigger_urls` - (Optional) The HTTP trigger URL for each Azure Function receiver, keyed by receiver name. Required for every Azure Function receiver.
- `logic_app_receiver_callback_urls` - (Optional) The callback URL for each Logic App receiver, keyed by receiver name. Required for every Logic App receiver.
- `webhook_receiver_service_uris` - (Optional) The service URI for each webhook receiver, keyed by receiver name. Required for every webhook receiver.
DESCRIPTION
  nullable    = false
  sensitive   = true

  validation {
    condition = alltrue([
      for key in nonsensitive(keys(var.service_health_alert_receiver_secrets)) :
      contains([
        for alert_key, alert in var.service_health_alerts : alert_key
        if alert.action_group != null ? alert.action_group.existing_action_group == null : false
      ], key)
    ])
    error_message = "Each key in `service_health_alert_receiver_secrets` must match a `service_health_alerts` key whose action group is created by this module."
  }
}

variable "service_health_alerts" {
  type = map(object({
    service_health_alert = string
    name                 = optional(string)
    description          = optional(string)
    enabled              = optional(bool, true)
    action_group = optional(object({
      existing_action_group = optional(object({
        resource_id = string
      }))
      name             = optional(string)
      group_short_name = optional(string)
      enabled          = optional(bool, true)
      arm_role_receivers = optional(list(object({
        name                    = string
        role_id                 = string
        use_common_alert_schema = optional(bool, false)
      })), [])
      automation_runbook_receivers = optional(list(object({
        name                           = string
        automation_account_resource_id = string
        is_global_runbook              = bool
        runbook_name                   = string
        webhook_resource_id            = string
        use_common_alert_schema        = optional(bool, false)
      })), [])
      azure_app_push_receivers = optional(list(object({
        name          = string
        email_address = string
      })), [])
      azure_function_receivers = optional(list(object({
        name                     = string
        function_app_resource_id = string
        function_name            = string
        use_common_alert_schema  = optional(bool, false)
      })), [])
      email_receivers = optional(list(object({
        name                    = string
        email_address           = string
        use_common_alert_schema = optional(bool, false)
      })), [])
      event_hub_receivers = optional(list(object({
        name                    = string
        event_hub_name          = string
        event_hub_namespace     = string
        subscription_id         = string
        tenant_id               = optional(string)
        use_common_alert_schema = optional(bool, false)
      })), [])
      itsm_receivers = optional(list(object({
        name                 = string
        connection_id        = string
        region               = string
        ticket_configuration = string
        workspace_id         = string
      })), [])
      logic_app_receivers = optional(list(object({
        name                    = string
        logic_app_resource_id   = string
        use_common_alert_schema = optional(bool, false)
      })), [])
      sms_receivers = optional(list(object({
        name         = string
        country_code = string
        phone_number = string
      })), [])
      voice_receivers = optional(list(object({
        name         = string
        country_code = string
        phone_number = string
      })), [])
      webhook_receivers = optional(list(object({
        name                    = string
        identifier_uri          = optional(string)
        object_id               = optional(string)
        tenant_id               = optional(string)
        use_aad_auth            = optional(bool, false)
        use_common_alert_schema = optional(bool, false)
      })), [])
    }))
  }))
  default = {
    resource_health_unhealthy = {
      service_health_alert = "Resource Health Unhealthy"
    }
    service_health_advisory = {
      service_health_alert = "Service Health Advisory"
    }
    service_health_incident = {
      service_health_alert = "Service Health Incident"
    }
    service_health_maintenance = {
      service_health_alert = "Service Health Maintenance"
    }
    service_health_security = {
      service_health_alert = "Service Health Security"
    }
  }
  description = <<DESCRIPTION
A map of service health alerts to create as activity log alerts scoped to the target subscription. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time. Defaults to one alert for each supported `service_health_alert` value. Set to `{}` to create no alerts.

- `service_health_alert` - (Required) The alert condition to deploy. Possible values are:
  - `Service Health Incident` - `ServiceHealth` events with incident type `Incident` (service issues).
  - `Service Health Maintenance` - `ServiceHealth` events with incident type `Maintenance` (planned maintenance).
  - `Service Health Advisory` - `ServiceHealth` events with incident type `ActionRequired` (health advisories).
  - `Service Health Security` - `ServiceHealth` events with incident type `Security` (security advisories).
  - `Resource Health Unhealthy` - `ResourceHealth` events with a platform- or user-initiated cause and a current health status of `Degraded` or `Unavailable`.
- `name` - (Optional) The name of the activity log alert. Defaults to the `service_health_alert` value with spaces removed and an `Alert` suffix, for example `ServiceHealthIncidentAlert`. Names must be unique within the map, 1-260 characters, contain only alphanumerics, underscores, parentheses, hyphens and periods, and not end with a period.
- `description` - (Optional) The description of the activity log alert. Defaults to a description of the selected `service_health_alert`.
- `enabled` - (Optional) Whether the activity log alert is enabled. Defaults to `true`.
- `action_group` - (Optional) An action group dedicated to this alert, created by the module or referenced by ID. To notify the same receivers from several alerts, use `shared_action_groups` instead. Receiver names must be unique across all receiver types of the action group. An alert can notify at most five action groups in total, counting its own and the shared action groups that target it.
  - `existing_action_group` - (Optional) Use an existing action group instead of creating one. When set, all other `action_group` attributes are ignored and not validated.
    - `resource_id` - (Required) The resource ID of the existing action group.
  - `name` - (Optional) The name of the action group created by this module. Defaults to `<alert name>-action-group`. Action group names must be unique, case-insensitively, across all action groups created by the module, 1-260 characters, must not contain `:<>+/&%\?|` or control characters, and must not end with a space or period.
  - `group_short_name` - (Optional) The short name of the action group, used in SMS and email notifications. Maximum 12 characters. Defaults to the first 12 characters of the alert name.
  - `enabled` - (Optional) Whether the action group is enabled. Defaults to `true`.
  - `arm_role_receivers` - (Optional) A list of Azure Resource Manager role receivers.
    - `name` - (Required) The name of the receiver.
    - `role_id` - (Required) The ID of the role definition. Action groups only email members of Owner (`8e3af657-a8ff-443c-a75c-2fe8c4bcb635`), Contributor (`b24988ac-6180-42a0-ab88-20f7382dd24c`), Reader (`acdd72a7-3385-48ef-bd42-f606fba81ae7`), Monitoring Contributor (`749f88d5-cbae-40b8-bcfc-e573ddc772fa`) and Monitoring Reader (`43d0d8ad-25c7-4714-9337-8ba259a9fe05`).
    - `use_common_alert_schema` - (Optional) Whether to use the common alert schema. Defaults to `false`.
  - `automation_runbook_receivers` - (Optional) A list of Azure Automation runbook receivers. The webhook URI is supplied through `service_health_alert_receiver_secrets`.
    - `name` - (Required) The name of the receiver.
    - `automation_account_resource_id` - (Required) The resource ID of the Automation account.
    - `is_global_runbook` - (Required) Whether the runbook is a global runbook.
    - `runbook_name` - (Required) The name of the runbook.
    - `webhook_resource_id` - (Required) The resource ID of the Automation webhook.
    - `use_common_alert_schema` - (Optional) Whether to use the common alert schema. Defaults to `false`.
  - `azure_app_push_receivers` - (Optional) A list of Azure mobile app push receivers.
    - `name` - (Required) The name of the receiver.
    - `email_address` - (Required) The email address registered for the Azure mobile app.
  - `azure_function_receivers` - (Optional) A list of Azure Function receivers. The HTTP trigger URL is supplied through `service_health_alert_receiver_secrets`.
    - `name` - (Required) The name of the receiver.
    - `function_app_resource_id` - (Required) The resource ID of the Function App.
    - `function_name` - (Required) The name of the function in the Function App.
    - `use_common_alert_schema` - (Optional) Whether to use the common alert schema. Defaults to `false`.
  - `email_receivers` - (Optional) A list of email receivers.
    - `name` - (Required) The name of the receiver.
    - `email_address` - (Required) The email address of the receiver.
    - `use_common_alert_schema` - (Optional) Whether to use the common alert schema. Defaults to `false`.
  - `event_hub_receivers` - (Optional) A list of Event Hub receivers.
    - `name` - (Required) The name of the receiver.
    - `event_hub_name` - (Required) The name of the Event Hub.
    - `event_hub_namespace` - (Required) The name of the Event Hub namespace.
    - `subscription_id` - (Required) The ID of the subscription that contains the Event Hub namespace.
    - `tenant_id` - (Optional) The ID of the tenant that contains the Event Hub namespace.
    - `use_common_alert_schema` - (Optional) Whether to use the common alert schema. Defaults to `false`.
  - `itsm_receivers` - (Optional) A list of IT Service Management receivers.
    - `name` - (Required) The name of the receiver.
    - `connection_id` - (Required) The unique identifier of the ITSM connection.
    - `region` - (Required) The region of the Log Analytics workspace that holds the ITSM connection.
    - `ticket_configuration` - (Required) A JSON string with the ticket configuration of the ITSM action. Build it with `jsonencode`.
    - `workspace_id` - (Required) The Log Analytics workspace identifier of the ITSM connection.
  - `logic_app_receivers` - (Optional) A list of Logic App receivers. The callback URL is supplied through `service_health_alert_receiver_secrets`.
    - `name` - (Required) The name of the receiver.
    - `logic_app_resource_id` - (Required) The resource ID of the Logic App.
    - `use_common_alert_schema` - (Optional) Whether to use the common alert schema. Defaults to `false`.
  - `sms_receivers` - (Optional) A list of SMS receivers.
    - `name` - (Required) The name of the receiver.
    - `country_code` - (Required) The country code of the phone number.
    - `phone_number` - (Required) The phone number.
  - `voice_receivers` - (Optional) A list of voice call receivers.
    - `name` - (Required) The name of the receiver.
    - `country_code` - (Required) The country code of the phone number.
    - `phone_number` - (Required) The phone number.
  - `webhook_receivers` - (Optional) A list of webhook receivers. The service URI is supplied through `service_health_alert_receiver_secrets`.
    - `name` - (Required) The name of the receiver.
    - `identifier_uri` - (Optional) The identifier URI for Microsoft Entra authentication.
    - `object_id` - (Optional) The object ID of the webhook application for Microsoft Entra authentication. Required when `use_aad_auth` is `true`.
    - `tenant_id` - (Optional) The tenant ID for Microsoft Entra authentication.
    - `use_aad_auth` - (Optional) Whether to use Microsoft Entra authentication. Defaults to `false`.
    - `use_common_alert_schema` - (Optional) Whether to use the common alert schema. Defaults to `false`.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for alert in values(var.service_health_alerts) :
      contains(["Resource Health Unhealthy", "Service Health Advisory", "Service Health Incident", "Service Health Maintenance", "Service Health Security"], alert.service_health_alert)
    ])
    error_message = "Each `service_health_alert` must be one of `Resource Health Unhealthy`, `Service Health Advisory`, `Service Health Incident`, `Service Health Maintenance` or `Service Health Security`."
  }
  validation {
    condition = alltrue([
      for alert in values(var.service_health_alerts) :
      alert.name == null ? true : can(regex("^[-\\w\\._\\(\\)]{1,260}$", alert.name)) && !endswith(alert.name, ".")
    ])
    error_message = "Each alert `name` must be 1-260 characters, contain only alphanumerics, underscores, parentheses, hyphens and periods, and not end with a period."
  }
  validation {
    condition = length(distinct([
      for alert in values(var.service_health_alerts) :
      lower(coalesce(alert.name, "${replace(alert.service_health_alert, " ", "")}Alert"))
    ])) == length(var.service_health_alerts)
    error_message = "Alert names must be unique. Set `name` when more than one alert uses the same `service_health_alert` value."
  }
  validation {
    condition = alltrue([
      for alert in values(var.service_health_alerts) :
      alert.action_group == null ? true : alert.action_group.existing_action_group != null ? true : alert.action_group.group_short_name == null ? true : length(alert.action_group.group_short_name) <= 12
    ])
    error_message = "Each action group `group_short_name` must be at most 12 characters."
  }
  validation {
    condition = alltrue([
      for alert in values(var.service_health_alerts) :
      alert.action_group == null ? true : alert.action_group.existing_action_group == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Insights/actionGroups", alert.action_group.existing_action_group.resource_id))
    ])
    error_message = "Each `action_group.existing_action_group.resource_id` must be a valid action group resource ID."
  }
  validation {
    condition = alltrue([
      for names in [
        for alert in values(var.service_health_alerts) : alert.action_group == null ? [] : alert.action_group.existing_action_group != null ? [] : flatten([
          for receivers in [
            alert.action_group.arm_role_receivers,
            alert.action_group.automation_runbook_receivers,
            alert.action_group.azure_app_push_receivers,
            alert.action_group.azure_function_receivers,
            alert.action_group.email_receivers,
            alert.action_group.event_hub_receivers,
            alert.action_group.itsm_receivers,
            alert.action_group.logic_app_receivers,
            alert.action_group.sms_receivers,
            alert.action_group.voice_receivers,
            alert.action_group.webhook_receivers,
          ] : [for receiver in receivers : receiver.name]
        ])
      ] : length(distinct(names)) == length(names)
    ])
    error_message = "Receiver names must be unique across all receiver types of an action group."
  }
  validation {
    condition = alltrue(flatten([
      for alert in values(var.service_health_alerts) : [
        for receiver in alert.action_group == null ? [] : alert.action_group.existing_action_group != null ? [] : alert.action_group.webhook_receivers :
        receiver.use_aad_auth ? receiver.object_id != null : true
      ]
    ]))
    error_message = "Each webhook receiver with `use_aad_auth = true` must set `object_id`."
  }
  validation {
    condition = alltrue(flatten([
      for alert in values(var.service_health_alerts) : [
        for receiver in alert.action_group == null ? [] : alert.action_group.existing_action_group != null ? [] : alert.action_group.automation_runbook_receivers :
        can(provider::azapi::parse_resource_id("Microsoft.Automation/automationAccounts", receiver.automation_account_resource_id)) && can(provider::azapi::parse_resource_id("Microsoft.Automation/automationAccounts/webhooks", receiver.webhook_resource_id))
      ]
    ]))
    error_message = "Each automation runbook receiver must use a valid Automation account resource ID and a valid Automation webhook resource ID."
  }
  validation {
    condition = alltrue(flatten([
      for alert in values(var.service_health_alerts) : [
        for receiver in alert.action_group == null ? [] : alert.action_group.existing_action_group != null ? [] : alert.action_group.azure_function_receivers :
        can(provider::azapi::parse_resource_id("Microsoft.Web/sites", receiver.function_app_resource_id))
      ]
    ]))
    error_message = "Each Azure Function receiver `function_app_resource_id` must be a valid Function App resource ID."
  }
  validation {
    condition = alltrue(flatten([
      for alert in values(var.service_health_alerts) : [
        for receiver in alert.action_group == null ? [] : alert.action_group.existing_action_group != null ? [] : alert.action_group.logic_app_receivers :
        can(provider::azapi::parse_resource_id("Microsoft.Logic/workflows", receiver.logic_app_resource_id))
      ]
    ]))
    error_message = "Each Logic App receiver `logic_app_resource_id` must be a valid Logic App resource ID."
  }
}

variable "shared_action_group_receiver_secrets" {
  type = map(object({
    automation_runbook_receiver_service_uris  = optional(map(string), {})
    azure_function_receiver_http_trigger_urls = optional(map(string), {})
    logic_app_receiver_callback_urls          = optional(map(string), {})
    webhook_receiver_service_uris             = optional(map(string), {})
  }))
  default     = {}
  description = <<DESCRIPTION
Secret URLs for the receivers of the shared action groups, keyed by the `shared_action_groups` key and then by receiver `name`. Same attributes and behavior as `service_health_alert_receiver_secrets`. Supplying a non-empty value requires Terraform 1.11 or later.
DESCRIPTION
  nullable    = false
  sensitive   = true

  validation {
    condition = alltrue([
      for key in nonsensitive(keys(var.shared_action_group_receiver_secrets)) :
      contains(keys(var.shared_action_groups), key)
    ])
    error_message = "Each key in `shared_action_group_receiver_secrets` must match a `shared_action_groups` key."
  }
}

variable "shared_action_groups" {
  type = map(object({
    name                      = optional(string)
    group_short_name          = optional(string)
    enabled                   = optional(bool, true)
    service_health_alert_keys = optional(set(string))
    arm_role_receivers = optional(list(object({
      name                    = string
      role_id                 = string
      use_common_alert_schema = optional(bool, false)
    })), [])
    automation_runbook_receivers = optional(list(object({
      name                           = string
      automation_account_resource_id = string
      is_global_runbook              = bool
      runbook_name                   = string
      webhook_resource_id            = string
      use_common_alert_schema        = optional(bool, false)
    })), [])
    azure_app_push_receivers = optional(list(object({
      name          = string
      email_address = string
    })), [])
    azure_function_receivers = optional(list(object({
      name                     = string
      function_app_resource_id = string
      function_name            = string
      use_common_alert_schema  = optional(bool, false)
    })), [])
    email_receivers = optional(list(object({
      name                    = string
      email_address           = string
      use_common_alert_schema = optional(bool, false)
    })), [])
    event_hub_receivers = optional(list(object({
      name                    = string
      event_hub_name          = string
      event_hub_namespace     = string
      subscription_id         = string
      tenant_id               = optional(string)
      use_common_alert_schema = optional(bool, false)
    })), [])
    itsm_receivers = optional(list(object({
      name                 = string
      connection_id        = string
      region               = string
      ticket_configuration = string
      workspace_id         = string
    })), [])
    logic_app_receivers = optional(list(object({
      name                    = string
      logic_app_resource_id   = string
      use_common_alert_schema = optional(bool, false)
    })), [])
    sms_receivers = optional(list(object({
      name         = string
      country_code = string
      phone_number = string
    })), [])
    voice_receivers = optional(list(object({
      name         = string
      country_code = string
      phone_number = string
    })), [])
    webhook_receivers = optional(list(object({
      name                    = string
      identifier_uri          = optional(string)
      object_id               = optional(string)
      tenant_id               = optional(string)
      use_aad_auth            = optional(bool, false)
      use_common_alert_schema = optional(bool, false)
    })), [])
  }))
  default     = {}
  description = <<DESCRIPTION
A map of action groups created once by the module and notified by several alerts. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time. An alert can be notified by its own `action_group` and by any number of shared action groups.

- `name` - (Optional) The name of the action group. Defaults to `ag-<map key>`. The same naming rules as `action_group.name` in `service_health_alerts` apply.
- `group_short_name` - (Optional) The short name used in SMS and email notifications. Maximum 12 characters. Defaults to the first 12 characters of the name.
- `enabled` - (Optional) Whether the action group is enabled. Defaults to `true`.
- `service_health_alert_keys` - (Optional) The `service_health_alerts` keys of the alerts that notify this action group. Defaults to `null`, which means every alert. An alert can notify at most five action groups in total.
- `arm_role_receivers`, `automation_runbook_receivers`, `azure_app_push_receivers`, `azure_function_receivers`, `email_receivers`, `event_hub_receivers`, `itsm_receivers`, `logic_app_receivers`, `sms_receivers`, `voice_receivers`, `webhook_receivers` - (Optional) Receiver lists with the same attributes as `action_group` in `service_health_alerts`. Secret URLs go in `shared_action_group_receiver_secrets`.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for action_group in values(var.shared_action_groups) :
      action_group.service_health_alert_keys == null ? true : alltrue([for key in action_group.service_health_alert_keys : contains(keys(var.service_health_alerts), key)])
    ])
    error_message = "Each `service_health_alert_keys` entry must match a `service_health_alerts` key."
  }
  validation {
    condition = alltrue([
      for action_group in values(var.shared_action_groups) :
      action_group.group_short_name == null ? true : length(action_group.group_short_name) <= 12
    ])
    error_message = "Each shared action group `group_short_name` must be at most 12 characters."
  }
  validation {
    condition = alltrue([
      for names in [
        for action_group in values(var.shared_action_groups) : flatten([
          for receivers in [
            action_group.arm_role_receivers,
            action_group.automation_runbook_receivers,
            action_group.azure_app_push_receivers,
            action_group.azure_function_receivers,
            action_group.email_receivers,
            action_group.event_hub_receivers,
            action_group.itsm_receivers,
            action_group.logic_app_receivers,
            action_group.sms_receivers,
            action_group.voice_receivers,
            action_group.webhook_receivers,
          ] : [for receiver in receivers : receiver.name]
        ])
      ] : length(distinct(names)) == length(names)
    ])
    error_message = "Receiver names must be unique across all receiver types of a shared action group."
  }
  validation {
    condition = alltrue(flatten([
      for action_group in values(var.shared_action_groups) : [
        for receiver in action_group.webhook_receivers :
        receiver.use_aad_auth ? receiver.object_id != null : true
      ]
    ]))
    error_message = "Each webhook receiver with `use_aad_auth = true` must set `object_id`."
  }
  validation {
    condition = alltrue(flatten([
      for action_group in values(var.shared_action_groups) : [
        for receiver in action_group.automation_runbook_receivers :
        can(provider::azapi::parse_resource_id("Microsoft.Automation/automationAccounts", receiver.automation_account_resource_id)) && can(provider::azapi::parse_resource_id("Microsoft.Automation/automationAccounts/webhooks", receiver.webhook_resource_id))
      ]
    ]))
    error_message = "Each automation runbook receiver must use a valid Automation account resource ID and a valid Automation webhook resource ID."
  }
  validation {
    condition = alltrue(flatten([
      for action_group in values(var.shared_action_groups) : [
        for receiver in action_group.azure_function_receivers :
        can(provider::azapi::parse_resource_id("Microsoft.Web/sites", receiver.function_app_resource_id))
      ]
    ]))
    error_message = "Each Azure Function receiver `function_app_resource_id` must be a valid Function App resource ID."
  }
  validation {
    condition = alltrue(flatten([
      for action_group in values(var.shared_action_groups) : [
        for receiver in action_group.logic_app_receivers :
        can(provider::azapi::parse_resource_id("Microsoft.Logic/workflows", receiver.logic_app_resource_id))
      ]
    ]))
    error_message = "Each Logic App receiver `logic_app_resource_id` must be a valid Logic App resource ID."
  }
}

variable "subscription_id" {
  type        = string
  default     = null
  description = "The ID of the subscription to monitor and deploy the alerts into. When `null`, the subscription of the current AzAPI provider context is used."

  validation {
    condition     = var.subscription_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "`subscription_id` must be a subscription ID in GUID format."
  }
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "timeouts" {
  type = object({
    create = optional(string)
    read   = optional(string)
    update = optional(string)
    delete = optional(string)
  })
  default     = null
  description = <<DESCRIPTION
Default per-operation timeouts applied to every `azapi` resource managed by the module. Defaults to `null` (provider defaults). Each value is a Go duration string (e.g. `30m`, `1h`).

- `create` - (Optional) Timeout for create operations.
- `read`   - (Optional) Timeout for read operations.
- `update` - (Optional) Timeout for update operations.
- `delete` - (Optional) Timeout for delete operations.
DESCRIPTION
}
