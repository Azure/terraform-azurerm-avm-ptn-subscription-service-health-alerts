locals {
  action_group_resource_ids = {
    for key, alert in var.service_health_alerts : key => (
      alert.action_group == null ? [] :
      alert.action_group.existing_action_group != null ? [alert.action_group.existing_action_group.resource_id] :
      [azapi_resource.action_group[key].id]
    )
  }
  action_groups = {
    for key, alert in var.service_health_alerts : key => {
      name = coalesce(alert.action_group.name, "${local.service_health_alert_names[key]}-action-group")
      body = {
        properties = {
          groupShortName = coalesce(alert.action_group.group_short_name, substr(local.service_health_alert_names[key], 0, 12))
          enabled        = alert.action_group.enabled
          armRoleReceivers = [
            for receiver in alert.action_group.arm_role_receivers : {
              name                 = receiver.name
              roleId               = receiver.role_id
              useCommonAlertSchema = receiver.use_common_alert_schema
            }
          ]
          automationRunbookReceivers = [
            for receiver in alert.action_group.automation_runbook_receivers : {
              name                 = receiver.name
              automationAccountId  = receiver.automation_account_resource_id
              isGlobalRunbook      = receiver.is_global_runbook
              runbookName          = receiver.runbook_name
              useCommonAlertSchema = receiver.use_common_alert_schema
              webhookResourceId    = receiver.webhook_resource_id
            }
          ]
          azureAppPushReceivers = [
            for receiver in alert.action_group.azure_app_push_receivers : {
              name         = receiver.name
              emailAddress = receiver.email_address
            }
          ]
          azureFunctionReceivers = [
            for receiver in alert.action_group.azure_function_receivers : {
              name                  = receiver.name
              functionAppResourceId = receiver.function_app_resource_id
              functionName          = receiver.function_name
              useCommonAlertSchema  = receiver.use_common_alert_schema
            }
          ]
          emailReceivers = [
            for receiver in alert.action_group.email_receivers : {
              name                 = receiver.name
              emailAddress         = receiver.email_address
              useCommonAlertSchema = receiver.use_common_alert_schema
            }
          ]
          eventHubReceivers = [
            for receiver in alert.action_group.event_hub_receivers : {
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
            for receiver in alert.action_group.itsm_receivers : {
              name                = receiver.name
              connectionId        = receiver.connection_id
              region              = receiver.region
              ticketConfiguration = receiver.ticket_configuration
              workspaceId         = receiver.workspace_id
            }
          ]
          logicAppReceivers = [
            for receiver in alert.action_group.logic_app_receivers : {
              name                 = receiver.name
              resourceId           = receiver.logic_app_resource_id
              useCommonAlertSchema = receiver.use_common_alert_schema
            }
          ]
          smsReceivers = [
            for receiver in alert.action_group.sms_receivers : {
              name        = receiver.name
              countryCode = receiver.country_code
              phoneNumber = receiver.phone_number
            }
          ]
          voiceReceivers = [
            for receiver in alert.action_group.voice_receivers : {
              name        = receiver.name
              countryCode = receiver.country_code
              phoneNumber = receiver.phone_number
            }
          ]
          webhookReceivers = [
            for receiver in alert.action_group.webhook_receivers : {
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
    } if alert.action_group != null ? alert.action_group.existing_action_group == null : false
  }
  action_group_receiver_names = {
    for key in keys(local.action_groups) : key => {
      automationRunbookReceivers = toset([for receiver in var.service_health_alerts[key].action_group.automation_runbook_receivers : receiver.name])
      azureFunctionReceivers     = toset([for receiver in var.service_health_alerts[key].action_group.azure_function_receivers : receiver.name])
      logicAppReceivers          = toset([for receiver in var.service_health_alerts[key].action_group.logic_app_receivers : receiver.name])
      webhookReceivers           = toset([for receiver in var.service_health_alerts[key].action_group.webhook_receivers : receiver.name])
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
    for key in keys(local.action_groups) : key => lookup(var.service_health_alert_receiver_secrets, key, {
      automation_runbook_receiver_service_uris  = {}
      azure_function_receiver_http_trigger_urls = {}
      logic_app_receiver_callback_urls          = {}
      webhook_receiver_service_uris             = {}
    })
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
