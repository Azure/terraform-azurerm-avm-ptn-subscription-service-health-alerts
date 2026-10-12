locals {
  action_group_configs = merge(
    {
      for key, alert in var.service_health_alerts : "alert/${key}" => {
        key              = key
        scope            = "alert"
        name             = coalesce(alert.action_group.name, "${local.service_health_alert_names[key]}-action-group")
        group_short_name = coalesce(alert.action_group.group_short_name, substr(local.service_health_alert_names[key], 0, 12))
        receivers        = alert.action_group
      } if alert.action_group != null ? alert.action_group.existing_action_group == null : false
    },
    {
      for key, action_group in var.shared_action_groups : "shared/${key}" => {
        key              = key
        scope            = "shared"
        name             = coalesce(action_group.name, "ag-${key}")
        group_short_name = coalesce(action_group.group_short_name, substr(coalesce(action_group.name, "ag-${key}"), 0, 12))
        receivers        = action_group
      }
    }
  )
  action_group_name_unique = {
    for key, config in local.action_group_configs : key => length([for other in values(local.action_group_configs) : other.name if lower(other.name) == lower(config.name)]) == 1
  }
  action_group_name_valid = {
    for key, config in local.action_group_configs : key => can(regex("^[^:<>*+/&%?|\\\\[:cntrl:]]{1,260}$", config.name)) && !endswith(config.name, " ") && !endswith(config.name, ".")
  }
  action_group_receiver_names = {
    for key, config in local.action_group_configs : key => {
      automationRunbookReceivers = toset([for receiver in config.receivers.automation_runbook_receivers : receiver.name])
      azureFunctionReceivers     = toset([for receiver in config.receivers.azure_function_receivers : receiver.name])
      logicAppReceivers          = toset([for receiver in config.receivers.logic_app_receivers : receiver.name])
      webhookReceivers           = toset([for receiver in config.receivers.webhook_receivers : receiver.name])
    }
  }
  action_group_receiver_secret_names = {
    for key, secrets in local.action_group_receiver_secrets : key => {
      automationRunbookReceivers = nonsensitive(toset(keys(secrets.automation_runbook_receiver_service_uris)))
      azureFunctionReceivers     = nonsensitive(toset(keys(secrets.azure_function_receiver_http_trigger_urls)))
      logicAppReceivers          = nonsensitive(toset(keys(secrets.logic_app_receiver_callback_urls)))
      webhookReceivers           = nonsensitive(toset(keys(secrets.webhook_receiver_service_uris)))
    }
  }
  action_group_receiver_secrets = {
    for key, config in local.action_group_configs : key => lookup(config.scope == "alert" ? var.service_health_alert_receiver_secrets : var.shared_action_group_receiver_secrets, config.key, {
      automation_runbook_receiver_service_uris  = {}
      azure_function_receiver_http_trigger_urls = {}
      logic_app_receiver_callback_urls          = {}
      webhook_receiver_service_uris             = {}
    })
  }
  action_group_receiver_secrets_valid = {
    for key, names in local.action_group_receiver_names : key => alltrue([
      for property in ["azureFunctionReceivers", "logicAppReceivers", "webhookReceivers"] :
      length(setsubtract(names[property], local.action_group_receiver_secret_names[key][property])) == 0 && length(setsubtract(local.action_group_receiver_secret_names[key][property], names[property])) == 0
    ]) && length(setsubtract(local.action_group_receiver_secret_names[key].automationRunbookReceivers, names.automationRunbookReceivers)) == 0
  }
  action_group_receivers = {
    for key, config in local.action_group_configs : key => {
      arm_role_receivers = {
        for index, receiver in config.receivers.arm_role_receivers : tostring(index) => receiver
      }
      automation_runbook_receivers = {
        for index, receiver in config.receivers.automation_runbook_receivers : tostring(index) => {
          name                    = receiver.name
          automation_account_id   = receiver.automation_account_resource_id
          is_global_runbook       = receiver.is_global_runbook
          runbook_name            = receiver.runbook_name
          webhook_resource_id     = receiver.webhook_resource_id
          use_common_alert_schema = receiver.use_common_alert_schema
          service_uri             = lookup(local.action_group_receiver_secrets[key].automation_runbook_receiver_service_uris, receiver.name, null)
        }
      }
      azure_app_push_receivers = {
        for index, receiver in config.receivers.azure_app_push_receivers : tostring(index) => receiver
      }
      azure_function_receivers = {
        for index, receiver in config.receivers.azure_function_receivers : tostring(index) => merge(receiver, {
          http_trigger_url = lookup(local.action_group_receiver_secrets[key].azure_function_receiver_http_trigger_urls, receiver.name, null)
        })
      }
      email_receivers = {
        for index, receiver in config.receivers.email_receivers : tostring(index) => receiver
      }
      event_hub_receivers = {
        for index, receiver in config.receivers.event_hub_receivers : tostring(index) => receiver
      }
      itsm_receivers = {
        for index, receiver in config.receivers.itsm_receivers : tostring(index) => receiver
      }
      logic_app_receivers = {
        for index, receiver in config.receivers.logic_app_receivers : tostring(index) => {
          name                    = receiver.name
          resource_id             = receiver.logic_app_resource_id
          use_common_alert_schema = receiver.use_common_alert_schema
          callback_url            = lookup(local.action_group_receiver_secrets[key].logic_app_receiver_callback_urls, receiver.name, null)
        }
      }
      sms_receivers = {
        for index, receiver in config.receivers.sms_receivers : tostring(index) => receiver
      }
      voice_receivers = {
        for index, receiver in config.receivers.voice_receivers : tostring(index) => receiver
      }
      webhook_receivers = {
        for index, receiver in config.receivers.webhook_receivers : tostring(index) => merge(receiver, {
          service_uri = lookup(local.action_group_receiver_secrets[key].webhook_receiver_service_uris, receiver.name, null)
        })
      }
    }
  }
  alert_action_group_resource_ids = {
    for key, alert in var.service_health_alerts : key => concat(
      alert.action_group == null ? [] : alert.action_group.existing_action_group != null ? [alert.action_group.existing_action_group.resource_id] : [module.action_group["alert/${key}"].resource_id],
      [
        for shared_key, shared in var.shared_action_groups : module.action_group["shared/${shared_key}"].resource_id
        if shared.service_health_alert_keys == null ? true : contains(shared.service_health_alert_keys, key)
      ],
    )
  }
  lock = var.lock == null ? null : {
    name = coalesce(var.lock.name, "lock-${var.lock.kind}")
    body = {
      properties = {
        level = var.lock.kind
        notes = coalesce(var.lock.notes, var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources.")
      }
    }
  }
  service_health_alert_conditions = {
    "Resource Health Unhealthy" = [
      {
        field  = "category"
        equals = "ResourceHealth"
      },
      {
        anyOf = [
          {
            field  = "properties.cause"
            equals = "PlatformInitiated"
          },
          {
            field  = "properties.cause"
            equals = "UserInitiated"
          },
        ]
      },
      {
        anyOf = [
          {
            field  = "properties.currentHealthStatus"
            equals = "Degraded"
          },
          {
            field  = "properties.currentHealthStatus"
            equals = "Unavailable"
          },
        ]
      },
    ]
    "Service Health Advisory" = [
      {
        field  = "category"
        equals = "ServiceHealth"
      },
      {
        field  = "properties.incidentType"
        equals = "ActionRequired"
      },
    ]
    "Service Health Incident" = [
      {
        field  = "category"
        equals = "ServiceHealth"
      },
      {
        field  = "properties.incidentType"
        equals = "Incident"
      },
    ]
    "Service Health Maintenance" = [
      {
        field  = "category"
        equals = "ServiceHealth"
      },
      {
        field  = "properties.incidentType"
        equals = "Maintenance"
      },
    ]
    "Service Health Security" = [
      {
        field  = "category"
        equals = "ServiceHealth"
      },
      {
        field  = "properties.incidentType"
        equals = "Security"
      },
    ]
  }
  service_health_alert_descriptions = {
    "Resource Health Unhealthy"  = "Alert for Resource Health Unhealthy status."
    "Service Health Advisory"    = "Alert for Service Health Advisory incidents."
    "Service Health Incident"    = "Alert for Service Health Incident occurrences."
    "Service Health Maintenance" = "Alert for Service Health Maintenance events."
    "Service Health Security"    = "Alert for Service Health Security incidents."
  }
  service_health_alert_names = {
    for key, alert in var.service_health_alerts : key => coalesce(alert.name, "${replace(alert.service_health_alert, " ", "")}Alert")
  }
  subscription_id          = provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id).subscription_id
  subscription_resource_id = "/subscriptions/${local.subscription_id}"
}
