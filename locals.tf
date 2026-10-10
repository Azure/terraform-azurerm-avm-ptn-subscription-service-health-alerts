locals {
  action_group_bodies = {
    for key, config in local.action_group_configs : key => {
      properties = {
        groupShortName = config.group_short_name
        enabled        = config.receivers.enabled
        armRoleReceivers = [
          for receiver in config.receivers.arm_role_receivers : {
            name                 = receiver.name
            roleId               = receiver.role_id
            useCommonAlertSchema = receiver.use_common_alert_schema
          }
        ]
        automationRunbookReceivers = [
          for receiver in config.receivers.automation_runbook_receivers : {
            name                 = receiver.name
            automationAccountId  = receiver.automation_account_resource_id
            isGlobalRunbook      = receiver.is_global_runbook
            runbookName          = receiver.runbook_name
            useCommonAlertSchema = receiver.use_common_alert_schema
            webhookResourceId    = receiver.webhook_resource_id
          }
        ]
        azureAppPushReceivers = [
          for receiver in config.receivers.azure_app_push_receivers : {
            name         = receiver.name
            emailAddress = receiver.email_address
          }
        ]
        azureFunctionReceivers = [
          for receiver in config.receivers.azure_function_receivers : {
            name                  = receiver.name
            functionAppResourceId = receiver.function_app_resource_id
            functionName          = receiver.function_name
            useCommonAlertSchema  = receiver.use_common_alert_schema
          }
        ]
        emailReceivers = [
          for receiver in config.receivers.email_receivers : {
            name                 = receiver.name
            emailAddress         = receiver.email_address
            useCommonAlertSchema = receiver.use_common_alert_schema
          }
        ]
        eventHubReceivers = [
          for receiver in config.receivers.event_hub_receivers : {
            for property, value in {
              name                 = receiver.name
              eventHubName         = receiver.event_hub_name
              eventHubNameSpace    = receiver.event_hub_namespace
              subscriptionId       = receiver.subscription_id
              tenantId             = receiver.tenant_id
              useCommonAlertSchema = receiver.use_common_alert_schema
            } : property => value if value != null
          }
        ]
        itsmReceivers = [
          for receiver in config.receivers.itsm_receivers : {
            name                = receiver.name
            connectionId        = receiver.connection_id
            region              = receiver.region
            ticketConfiguration = receiver.ticket_configuration
            workspaceId         = receiver.workspace_id
          }
        ]
        logicAppReceivers = [
          for receiver in config.receivers.logic_app_receivers : {
            name                 = receiver.name
            resourceId           = receiver.logic_app_resource_id
            useCommonAlertSchema = receiver.use_common_alert_schema
          }
        ]
        smsReceivers = [
          for receiver in config.receivers.sms_receivers : {
            name        = receiver.name
            countryCode = receiver.country_code
            phoneNumber = receiver.phone_number
          }
        ]
        voiceReceivers = [
          for receiver in config.receivers.voice_receivers : {
            name        = receiver.name
            countryCode = receiver.country_code
            phoneNumber = receiver.phone_number
          }
        ]
        webhookReceivers = [
          for receiver in config.receivers.webhook_receivers : {
            for property, value in {
              name                 = receiver.name
              identifierUri        = receiver.identifier_uri
              objectId             = receiver.object_id
              tenantId             = receiver.tenant_id
              useAadAuth           = receiver.use_aad_auth
              useCommonAlertSchema = receiver.use_common_alert_schema
            } : property => value if value != null
          }
        ]
      }
    }
  }
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
    for key, config in local.action_group_configs : key => can(regex("^[^:<>+/&%?|\\\\[:cntrl:]]{1,260}$", config.name)) && !endswith(config.name, " ") && !endswith(config.name, ".")
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
  action_group_sensitive_bodies = {
    for key, secrets in local.action_group_receiver_secrets : key => {
      properties = {
        for property, receivers in {
          automationRunbookReceivers = [for name, uri in secrets.automation_runbook_receiver_service_uris : { name = name, serviceUri = uri }]
          azureFunctionReceivers     = [for name, url in secrets.azure_function_receiver_http_trigger_urls : { name = name, httpTriggerUrl = url }]
          logicAppReceivers          = [for name, url in secrets.logic_app_receiver_callback_urls : { name = name, callbackUrl = url }]
          webhookReceivers           = [for name, uri in secrets.webhook_receiver_service_uris : { name = name, serviceUri = uri }]
        } : property => receivers if length(local.action_group_receiver_secret_names[key][property]) > 0
      }
    } if length(flatten([for names in values(local.action_group_receiver_secret_names[key]) : tolist(names)])) > 0
  }
  alert_action_groups = {
    for key, config in local.action_group_configs : config.key => key if config.scope == "alert"
  }
  alert_action_group_resource_ids = {
    for key, alert in var.service_health_alerts : key => concat(
      alert.action_group == null ? [] : alert.action_group.existing_action_group != null ? [alert.action_group.existing_action_group.resource_id] : [azapi_resource.action_group[key].id],
      [
        for shared_key, shared in var.shared_action_groups : azapi_resource.shared_action_group[shared_key].id
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
  resource_group_name        = coalesce(var.resource_group_name, "rg-asha-${local.subscription_id}")
  resource_group_resource_id = var.resource_group_creation_enabled ? azapi_resource.resource_group[0].id : provider::azapi::subscription_resource_id(local.subscription_id, "Microsoft.Resources/resourceGroups", [local.resource_group_name])
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
  subscription_id          = coalesce(var.subscription_id, data.azapi_client_config.current.subscription_id)
  subscription_resource_id = "/subscriptions/${local.subscription_id}"
}
