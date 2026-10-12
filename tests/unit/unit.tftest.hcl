mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000001"
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock"
    }
  }
}

override_resource {
  target = azapi_resource.action_group
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Insights/actionGroups/ag-mock"
  }
}

override_resource {
  target = azapi_resource.shared_action_group
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Insights/actionGroups/ag-shared-mock"
  }
}

override_resource {
  target = azapi_resource.service_health_alert
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Insights/activityLogAlerts/ala-mock"
  }
}

mock_provider "modtm" {}

mock_provider "random" {}

variables {
  location = "swedencentral"
}

run "defaults" {
  command = apply

  assert {
    condition     = length(azapi_resource.resource_group) == 1
    error_message = "The resource group should be created by default."
  }

  assert {
    condition     = azapi_resource.resource_group[0].name == "rg-asha-00000000-0000-0000-0000-000000000000"
    error_message = "The resource group name should default to rg-asha-<subscription ID>."
  }

  assert {
    condition     = azapi_resource.resource_group[0].parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "The resource group should be created in the current subscription."
  }

  assert {
    condition     = azapi_resource.resource_group[0].location == "swedencentral"
    error_message = "The resource group should use var.location."
  }

  assert {
    condition     = toset(keys(azapi_resource.service_health_alert)) == toset(["resource_health_unhealthy", "service_health_advisory", "service_health_incident", "service_health_maintenance", "service_health_security"])
    error_message = "All five alerts should be created by default."
  }

  assert {
    condition = alltrue([
      for alert in values(azapi_resource.service_health_alert) :
      alert.location == "global" && alert.parent_id == azapi_resource.resource_group[0].id && alert.body.properties.scopes == ["/subscriptions/00000000-0000-0000-0000-000000000000"] && alert.body.properties.enabled == true
    ])
    error_message = "Every alert should be global, enabled, deployed in the resource group and scoped to the subscription."
  }

  assert {
    condition = alltrue([
      for alert in values(azapi_resource.service_health_alert) :
      length(alert.body.properties.actions.actionGroups) == 0
    ])
    error_message = "Alerts should have no action groups by default."
  }

  assert {
    condition     = azapi_resource.service_health_alert["service_health_incident"].name == "ServiceHealthIncidentAlert"
    error_message = "The default alert name should be derived from the service health alert type."
  }

  assert {
    condition     = azapi_resource.service_health_alert["resource_health_unhealthy"].name == "ResourceHealthUnhealthyAlert"
    error_message = "The default resource health alert name should be ResourceHealthUnhealthyAlert."
  }

  assert {
    condition     = azapi_resource.service_health_alert["service_health_incident"].body.properties.description == "Alert for Service Health Incident occurrences."
    error_message = "The default alert description should be set."
  }

  assert {
    condition = azapi_resource.service_health_alert["service_health_incident"].body.properties.condition.allOf == [
      { field = "category", equals = "ServiceHealth" },
      { field = "properties.incidentType", equals = "Incident" },
    ]
    error_message = "The incident alert should match ServiceHealth events with incident type Incident."
  }

  assert {
    condition     = azapi_resource.service_health_alert["service_health_advisory"].body.properties.condition.allOf[1].equals == "ActionRequired"
    error_message = "The advisory alert should match incident type ActionRequired."
  }

  assert {
    condition     = azapi_resource.service_health_alert["service_health_maintenance"].body.properties.condition.allOf[1].equals == "Maintenance"
    error_message = "The maintenance alert should match incident type Maintenance."
  }

  assert {
    condition     = azapi_resource.service_health_alert["service_health_security"].body.properties.condition.allOf[1].equals == "Security"
    error_message = "The security alert should match incident type Security."
  }

  assert {
    condition     = azapi_resource.service_health_alert["resource_health_unhealthy"].body.properties.condition.allOf[0].equals == "ResourceHealth"
    error_message = "The resource health alert should match the ResourceHealth category."
  }

  assert {
    condition     = length(azapi_resource.service_health_alert["resource_health_unhealthy"].body.properties.condition.allOf[2].anyOf) == 2
    error_message = "The resource health alert should match Degraded or Unavailable health status."
  }

  assert {
    condition     = length(azapi_resource.action_group) == 0
    error_message = "No action groups should be created by default."
  }

  assert {
    condition     = length(azapi_resource.lock_resource_group) + length(azapi_resource.lock_service_health_alert) + length(azapi_resource.lock_action_group) == 0
    error_message = "No locks should be created by default."
  }

  assert {
    condition     = azapi_resource.service_health_alert["service_health_incident"].type == "Microsoft.Insights/activityLogAlerts@2026-01-01"
    error_message = "The alert should use the default activity log alert API version."
  }

  assert {
    condition     = azapi_resource.resource_group[0].type == "Microsoft.Resources/resourceGroups@2025-04-01"
    error_message = "The resource group should use the default API version."
  }

  assert {
    condition     = output.resource_group_resource_id == azapi_resource.resource_group[0].id
    error_message = "The resource group output should return the created resource group ID."
  }

  assert {
    condition     = output.service_health_alert_resource_ids["service_health_security"] == azapi_resource.service_health_alert["service_health_security"].id
    error_message = "The alert output should map keys to alert resource IDs."
  }

  assert {
    condition     = output.action_group_resource_ids == {}
    error_message = "The action group output should be empty when no action groups are created."
  }

  assert {
    condition     = length(modtm_telemetry.telemetry) == 1
    error_message = "Telemetry should be enabled by default."
  }
}

run "subscription_and_resource_group_name_overrides" {
  command = apply

  variables {
    subscription_id     = "11111111-1111-1111-1111-111111111111"
    resource_group_name = "rg-service-health"
  }

  assert {
    condition     = azapi_resource.resource_group[0].parent_id == "/subscriptions/11111111-1111-1111-1111-111111111111"
    error_message = "The resource group should be created in the supplied subscription."
  }

  assert {
    condition     = azapi_resource.resource_group[0].name == "rg-service-health"
    error_message = "The resource group should use the supplied name."
  }

  assert {
    condition = alltrue([
      for alert in values(azapi_resource.service_health_alert) :
      alert.body.properties.scopes == ["/subscriptions/11111111-1111-1111-1111-111111111111"]
    ])
    error_message = "Alerts should be scoped to the supplied subscription."
  }
}

run "existing_resource_group" {
  command = apply

  variables {
    resource_group_creation_enabled = false
    resource_group_name             = "rg-existing"
    lock = {
      kind = "CanNotDelete"
    }
  }

  assert {
    condition     = length(azapi_resource.resource_group) == 0
    error_message = "No resource group should be created when creation is disabled."
  }

  assert {
    condition     = output.resource_group_resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-existing"
    error_message = "The resource group ID should be built from the subscription and the supplied name."
  }

  assert {
    condition = alltrue([
      for alert in values(azapi_resource.service_health_alert) :
      alert.parent_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-existing"
    ])
    error_message = "Alerts should be deployed into the existing resource group."
  }

  assert {
    condition     = length(azapi_resource.lock_resource_group) == 0
    error_message = "An existing resource group should not be locked by the module."
  }

  assert {
    condition     = length(azapi_resource.lock_service_health_alert) == 5
    error_message = "Every alert should be locked."
  }
}

run "action_groups" {
  command = apply

  variables {
    tags = {
      environment = "test"
    }
    service_health_alert_receiver_secrets = {
      incident = {
        webhook_receiver_service_uris = {
          hook = "https://example.com/hook?token=secret"
        }
      }
    }
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          email_receivers = [
            {
              name          = "ops"
              email_address = "ops@example.com"
            }
          ]
          webhook_receivers = [
            {
              name = "hook"
            }
          ]
          arm_role_receivers = [
            {
              name                    = "owners"
              role_id                 = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635"
              use_common_alert_schema = true
            }
          ]
        }
      }
      maintenance = {
        service_health_alert = "Service Health Maintenance"
        name                 = "maintenance-alert"
        description          = "Planned maintenance."
        enabled              = false
        action_group = {
          name             = "ag-maintenance"
          group_short_name = "maint"
          enabled          = false
        }
      }
      existing = {
        service_health_alert = "Service Health Security"
        action_group = {
          existing_action_group = {
            resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.Insights/actionGroups/ag-shared"
          }
          email_receivers = [
            {
              name          = "ignored"
              email_address = "ignored@example.com"
            }
          ]
        }
      }
      none = {
        service_health_alert = "Service Health Advisory"
      }
    }
  }

  assert {
    condition     = toset(keys(azapi_resource.action_group)) == toset(["incident", "maintenance"])
    error_message = "Action groups should be created only for alerts without an existing action group."
  }

  assert {
    condition     = azapi_resource.action_group["incident"].name == "ServiceHealthIncidentAlert-action-group"
    error_message = "The action group name should default to <alert name>-action-group."
  }

  assert {
    condition     = azapi_resource.action_group["incident"].body.properties.groupShortName == "ServiceHealt"
    error_message = "The short name should default to the first 12 characters of the alert name."
  }

  assert {
    condition     = azapi_resource.action_group["incident"].location == "global" && azapi_resource.action_group["incident"].type == "Microsoft.Insights/actionGroups@2023-01-01"
    error_message = "Action groups should be global and use the default API version."
  }

  assert {
    condition = azapi_resource.action_group["incident"].body.properties.emailReceivers == [
      { name = "ops", emailAddress = "ops@example.com", useCommonAlertSchema = false },
    ]
    error_message = "Email receivers should be mapped to the ARM schema."
  }

  assert {
    condition = azapi_resource.action_group["incident"].body.properties.webhookReceivers == [
      { name = "hook", useAadAuth = false, useCommonAlertSchema = false },
    ]
    error_message = "The webhook service URI and unset optional webhook properties should be omitted from the body."
  }

  assert {
    condition = nonsensitive(local.action_group_sensitive_bodies["alert/incident"]) == {
      properties = {
        webhookReceivers = [{ name = "hook", serviceUri = "https://example.com/hook?token=secret" }]
      }
    }
    error_message = "The webhook service URI should be passed in the sensitive body, matched to its receiver by name."
  }

  assert {
    condition     = azapi_resource.action_group["incident"].sensitive_body == null
    error_message = "The write-only sensitive body should not be persisted in state."
  }

  assert {
    condition     = !contains(keys(local.action_group_sensitive_bodies), "alert/maintenance")
    error_message = "An action group without secret receivers should not get a sensitive body."
  }

  assert {
    condition     = azapi_resource.action_group["incident"].body.properties.armRoleReceivers[0].useCommonAlertSchema == true
    error_message = "ARM role receivers should honour use_common_alert_schema."
  }

  assert {
    condition     = length(azapi_resource.action_group["incident"].body.properties.smsReceivers) == 0
    error_message = "Unused receiver types should be empty lists."
  }

  assert {
    condition     = azapi_resource.action_group["maintenance"].name == "ag-maintenance" && azapi_resource.action_group["maintenance"].body.properties.groupShortName == "maint" && azapi_resource.action_group["maintenance"].body.properties.enabled == false
    error_message = "Explicit action group name, short name and enabled flag should be used."
  }

  assert {
    condition     = azapi_resource.action_group["incident"].tags == tomap({ environment = "test" })
    error_message = "Tags should be applied to action groups."
  }

  assert {
    condition     = azapi_resource.service_health_alert["incident"].body.properties.actions.actionGroups == [{ actionGroupId = azapi_resource.action_group["incident"].id }]
    error_message = "The alert should reference the action group created for it."
  }

  assert {
    condition     = azapi_resource.service_health_alert["existing"].body.properties.actions.actionGroups == [{ actionGroupId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.Insights/actionGroups/ag-shared" }]
    error_message = "The alert should reference the existing action group."
  }

  assert {
    condition     = length(azapi_resource.service_health_alert["none"].body.properties.actions.actionGroups) == 0
    error_message = "An alert without an action group should have no actions."
  }

  assert {
    condition     = azapi_resource.service_health_alert["maintenance"].name == "maintenance-alert" && azapi_resource.service_health_alert["maintenance"].body.properties.description == "Planned maintenance." && azapi_resource.service_health_alert["maintenance"].body.properties.enabled == false
    error_message = "Explicit alert name, description and enabled flag should be used."
  }

  assert {
    condition     = azapi_resource.service_health_alert["incident"].tags == tomap({ environment = "test" }) && azapi_resource.resource_group[0].tags == tomap({ environment = "test" })
    error_message = "Tags should be applied to alerts and the resource group."
  }

  assert {
    condition     = output.action_group_resource_ids == { for key, action_group in azapi_resource.action_group : key => action_group.id }
    error_message = "The action group output should list the created action groups."
  }
}

run "receiver_mapping" {
  command = apply

  variables {
    service_health_alert_receiver_secrets = {
      incident = {
        automation_runbook_receiver_service_uris = {
          runbook = "https://example.azure-automation.net/webhooks?token=secret"
        }
        azure_function_receiver_http_trigger_urls = {
          func = "https://fa.azurewebsites.net/api/notify?code=secret"
        }
        logic_app_receiver_callback_urls = {
          logic = "https://example.com/callback?sig=secret"
        }
      }
    }
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          automation_runbook_receivers = [
            {
              name                           = "runbook"
              automation_account_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Automation/automationAccounts/aa"
              is_global_runbook              = false
              runbook_name                   = "restart"
              webhook_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Automation/automationAccounts/aa/webhooks/wh"
            }
          ]
          azure_app_push_receivers = [
            {
              name          = "app"
              email_address = "app@example.com"
            }
          ]
          azure_function_receivers = [
            {
              name                     = "func"
              function_app_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Web/sites/fa"
              function_name            = "notify"
            }
          ]
          event_hub_receivers = [
            {
              name                = "eh"
              event_hub_name      = "alerts"
              event_hub_namespace = "ehns"
              subscription_id     = "00000000-0000-0000-0000-000000000000"
            }
          ]
          itsm_receivers = [
            {
              name                 = "itsm"
              connection_id        = "connection"
              region               = "westeurope"
              ticket_configuration = "{}"
              workspace_id         = "00000000-0000-0000-0000-000000000000|workspace"
            }
          ]
          logic_app_receivers = [
            {
              name                  = "logic"
              logic_app_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Logic/workflows/la"
            }
          ]
          sms_receivers = [
            {
              name         = "sms"
              country_code = "1"
              phone_number = "5555550100"
            }
          ]
          voice_receivers = [
            {
              name         = "voice"
              country_code = "1"
              phone_number = "5555550101"
            }
          ]
        }
      }
    }
  }

  assert {
    condition = azapi_resource.action_group["incident"].body.properties.automationRunbookReceivers == [
      {
        name                 = "runbook"
        automationAccountId  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Automation/automationAccounts/aa"
        isGlobalRunbook      = false
        runbookName          = "restart"
        useCommonAlertSchema = false
        webhookResourceId    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Automation/automationAccounts/aa/webhooks/wh"
      },
    ]
    error_message = "Automation runbook receivers should be mapped to the ARM schema without the webhook URI."
  }

  assert {
    condition     = azapi_resource.action_group["incident"].body.properties.azureAppPushReceivers == [{ name = "app", emailAddress = "app@example.com" }]
    error_message = "Azure app push receivers should be mapped to the ARM schema."
  }

  assert {
    condition = azapi_resource.action_group["incident"].body.properties.azureFunctionReceivers == [
      {
        name                  = "func"
        functionAppResourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Web/sites/fa"
        functionName          = "notify"
        useCommonAlertSchema  = false
      },
    ]
    error_message = "Azure Function receivers should be mapped to the ARM schema without the trigger URL."
  }

  assert {
    condition = azapi_resource.action_group["incident"].body.properties.eventHubReceivers == [
      {
        name                 = "eh"
        eventHubName         = "alerts"
        eventHubNameSpace    = "ehns"
        subscriptionId       = "00000000-0000-0000-0000-000000000000"
        useCommonAlertSchema = false
      },
    ]
    error_message = "Event Hub receivers should be mapped to the ARM schema without an unset tenant ID."
  }

  assert {
    condition = azapi_resource.action_group["incident"].body.properties.itsmReceivers == [
      {
        name                = "itsm"
        connectionId        = "connection"
        region              = "westeurope"
        ticketConfiguration = "{}"
        workspaceId         = "00000000-0000-0000-0000-000000000000|workspace"
      },
    ]
    error_message = "ITSM receivers should be mapped to the ARM schema."
  }

  assert {
    condition = azapi_resource.action_group["incident"].body.properties.logicAppReceivers == [
      {
        name                 = "logic"
        resourceId           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Logic/workflows/la"
        useCommonAlertSchema = false
      },
    ]
    error_message = "Logic App receivers should be mapped to the ARM schema without the callback URL."
  }

  assert {
    condition = nonsensitive(local.action_group_sensitive_bodies["alert/incident"]) == {
      properties = {
        automationRunbookReceivers = [{ name = "runbook", serviceUri = "https://example.azure-automation.net/webhooks?token=secret" }]
        azureFunctionReceivers     = [{ name = "func", httpTriggerUrl = "https://fa.azurewebsites.net/api/notify?code=secret" }]
        logicAppReceivers          = [{ name = "logic", callbackUrl = "https://example.com/callback?sig=secret" }]
      }
    }
    error_message = "Secret receiver URLs should be passed in the sensitive body, matched to their receivers by name."
  }

  assert {
    condition     = azapi_resource.action_group["incident"].body.properties.smsReceivers == [{ name = "sms", countryCode = "1", phoneNumber = "5555550100" }]
    error_message = "SMS receivers should be mapped to the ARM schema."
  }

  assert {
    condition     = azapi_resource.action_group["incident"].body.properties.voiceReceivers == [{ name = "voice", countryCode = "1", phoneNumber = "5555550101" }]
    error_message = "Voice receivers should be mapped to the ARM schema."
  }
}

run "lock" {
  command = apply

  variables {
    lock = {
      kind = "ReadOnly"
    }
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          email_receivers = [
            {
              name          = "ops"
              email_address = "ops@example.com"
            }
          ]
        }
      }
      security = {
        service_health_alert = "Service Health Security"
      }
    }
  }

  assert {
    condition     = length(azapi_resource.lock_resource_group) == 1 && length(azapi_resource.lock_service_health_alert) == 2 && length(azapi_resource.lock_action_group) == 1
    error_message = "The resource group, every alert and every created action group should be locked."
  }

  assert {
    condition     = azapi_resource.lock_service_health_alert["incident"].name == "lock-ReadOnly" && azapi_resource.lock_service_health_alert["incident"].body.properties.level == "ReadOnly"
    error_message = "The lock name and level should default from the lock kind."
  }

  assert {
    condition     = azapi_resource.lock_service_health_alert["incident"].body.properties.notes == "Cannot delete or modify the resource or its child resources."
    error_message = "ReadOnly locks should use the default ReadOnly notes."
  }

  assert {
    condition     = azapi_resource.lock_action_group["incident"].parent_id == azapi_resource.action_group["incident"].id
    error_message = "The action group lock should be scoped to the action group."
  }

  assert {
    condition     = azapi_resource.lock_resource_group[0].parent_id == azapi_resource.resource_group[0].id
    error_message = "The resource group lock should be scoped to the resource group."
  }
}

run "lock_custom_name_and_notes" {
  command = apply

  variables {
    lock = {
      kind  = "CanNotDelete"
      name  = "custom-lock"
      notes = "Managed by Terraform."
    }
  }

  assert {
    condition = alltrue([
      for lock in values(azapi_resource.lock_service_health_alert) :
      lock.name == "custom-lock" && lock.body.properties.notes == "Managed by Terraform." && lock.body.properties.level == "CanNotDelete"
    ])
    error_message = "Custom lock name and notes should be applied."
  }
}

run "azapi_interfaces" {
  command = apply

  variables {
    resource_types = {
      insights_activity_log_alerts = "Microsoft.Insights/activityLogAlerts@2020-10-01"
    }
    retry = {
      error_message_regex  = ["ScopeLocked"]
      interval_seconds     = 15
      max_interval_seconds = 60
    }
    timeouts = {
      create = "45m"
      delete = "20m"
    }
    ignore_body_changes = {
      insights_activity_log_alerts = ["properties.enabled"]
    }
  }

  assert {
    condition     = azapi_resource.service_health_alert["service_health_incident"].type == "Microsoft.Insights/activityLogAlerts@2020-10-01"
    error_message = "resource_types overrides should be applied."
  }

  assert {
    condition     = azapi_resource.resource_group[0].type == "Microsoft.Resources/resourceGroups@2025-04-01"
    error_message = "resource_types keys that are not overridden should keep their defaults."
  }

  assert {
    condition     = azapi_resource.service_health_alert["service_health_incident"].retry.error_message_regex == tolist(["ScopeLocked"]) && azapi_resource.resource_group[0].retry.interval_seconds == 15
    error_message = "retry should be applied to every resource."
  }

  assert {
    condition     = azapi_resource.service_health_alert["service_health_incident"].timeouts.create == "45m" && azapi_resource.resource_group[0].timeouts.delete == "20m"
    error_message = "timeouts should be applied to every resource."
  }
}

run "no_alerts" {
  command = apply

  variables {
    service_health_alerts = {}
    enable_telemetry      = false
  }

  assert {
    condition     = length(azapi_resource.service_health_alert) == 0 && length(azapi_resource.action_group) == 0
    error_message = "No alerts should be created when the map is empty."
  }

  assert {
    condition     = length(modtm_telemetry.telemetry) == 0
    error_message = "Telemetry should be disabled when enable_telemetry is false."
  }
}

run "invalid_service_health_alert" {
  command = plan

  variables {
    service_health_alerts = {
      bad = {
        service_health_alert = "Service Health Outage"
      }
    }
  }

  expect_failures = [var.service_health_alerts]
}

run "invalid_alert_name" {
  command = plan

  variables {
    service_health_alerts = {
      bad = {
        service_health_alert = "Service Health Incident"
        name                 = "has spaces"
      }
    }
  }

  expect_failures = [var.service_health_alerts]
}

run "duplicate_alert_names" {
  command = plan

  variables {
    service_health_alerts = {
      one = {
        service_health_alert = "Service Health Incident"
      }
      two = {
        service_health_alert = "Service Health Incident"
      }
    }
  }

  expect_failures = [var.service_health_alerts]
}

run "group_short_name_too_long" {
  command = plan

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          group_short_name = "thirteenchars"
        }
      }
    }
  }

  expect_failures = [var.service_health_alerts]
}

run "invalid_existing_action_group_resource_id" {
  command = plan

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          existing_action_group = {
            resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet"
          }
        }
      }
    }
  }

  expect_failures = [var.service_health_alerts]
}

run "invalid_logic_app_resource_id" {
  command = plan

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          logic_app_receivers = [
            {
              name                  = "logic"
              logic_app_resource_id = "not-a-resource-id"
            }
          ]
        }
      }
    }
  }

  expect_failures = [var.service_health_alerts]
}

run "invalid_subscription_id" {
  command = plan

  variables {
    subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.subscription_id]
}

run "invalid_resource_group_name" {
  command = plan

  variables {
    resource_group_name = "invalid name"
  }

  expect_failures = [var.resource_group_name]
}

run "invalid_lock_kind" {
  command = plan

  variables {
    lock = {
      kind = "None"
    }
  }

  expect_failures = [var.lock]
}

run "missing_receiver_secret" {
  command = plan

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          webhook_receivers = [
            {
              name = "hook"
            }
          ]
        }
      }
    }
  }

  expect_failures = [azapi_resource.action_group]
}

run "receiver_secret_for_unknown_receiver" {
  command = plan

  variables {
    service_health_alert_receiver_secrets = {
      incident = {
        webhook_receiver_service_uris = {
          hook = "https://example.com/hook"
          typo = "https://example.com/typo"
        }
      }
    }
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          webhook_receivers = [
            {
              name = "hook"
            }
          ]
        }
      }
    }
  }

  expect_failures = [azapi_resource.action_group]
}

run "receiver_secret_for_unknown_alert" {
  command = plan

  variables {
    service_health_alert_receiver_secrets = {
      not_an_alert = {
        webhook_receiver_service_uris = {
          hook = "https://example.com/hook"
        }
      }
    }
  }

  expect_failures = [var.service_health_alert_receiver_secrets]
}

run "duplicate_secret_receiver_names" {
  command = plan

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          webhook_receivers = [
            {
              name = "hook"
            },
            {
              name = "hook"
            }
          ]
        }
      }
    }
  }

  expect_failures = [var.service_health_alerts]
}

run "shared_action_groups" {
  command = apply

  variables {
    lock = {
      kind = "CanNotDelete"
    }
    shared_action_groups = {
      ops = {
        email_receivers = [
          {
            name          = "ops"
            email_address = "ops@example.com"
          },
          {
            name          = "oncall"
            email_address = "oncall@example.com"
          }
        ]
        sms_receivers = [
          {
            name         = "oncall-sms"
            country_code = "1"
            phone_number = "5555550100"
          }
        ]
      }
      security = {
        name                      = "ag-security-team"
        group_short_name          = "secteam"
        service_health_alert_keys = ["service_health_security"]
        webhook_receivers = [
          {
            name = "siem"
          }
        ]
      }
    }
    shared_action_group_receiver_secrets = {
      security = {
        webhook_receiver_service_uris = {
          siem = "https://example.com/siem?token=secret"
        }
      }
    }
    service_health_alerts = {
      service_health_incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          email_receivers = [
            {
              name          = "incident-team"
              email_address = "incident@example.com"
            }
          ]
        }
      }
      service_health_security = {
        service_health_alert = "Service Health Security"
      }
    }
  }

  assert {
    condition     = toset(keys(azapi_resource.shared_action_group)) == toset(["ops", "security"])
    error_message = "One action group should be created per shared_action_groups entry."
  }

  assert {
    condition     = azapi_resource.shared_action_group["ops"].name == "ag-ops" && azapi_resource.shared_action_group["ops"].body.properties.groupShortName == "ag-ops"
    error_message = "The shared action group name and short name should default from the map key."
  }

  assert {
    condition     = azapi_resource.shared_action_group["security"].name == "ag-security-team" && azapi_resource.shared_action_group["security"].body.properties.groupShortName == "secteam"
    error_message = "Explicit shared action group name and short name should be used."
  }

  assert {
    condition     = length(azapi_resource.shared_action_group["ops"].body.properties.emailReceivers) == 2 && length(azapi_resource.shared_action_group["ops"].body.properties.smsReceivers) == 1
    error_message = "A shared action group should hold several receivers."
  }

  assert {
    condition     = azapi_resource.shared_action_group["security"].body.properties.webhookReceivers == [{ name = "siem", useAadAuth = false, useCommonAlertSchema = false }]
    error_message = "The shared webhook service URI should not be in the body."
  }

  assert {
    condition = nonsensitive(local.action_group_sensitive_bodies["shared/security"]) == {
      properties = {
        webhookReceivers = [{ name = "siem", serviceUri = "https://example.com/siem?token=secret" }]
      }
    }
    error_message = "The shared webhook service URI should be passed in the sensitive body."
  }

  assert {
    condition = azapi_resource.service_health_alert["service_health_incident"].body.properties.actions.actionGroups == [
      { actionGroupId = azapi_resource.action_group["service_health_incident"].id },
      { actionGroupId = azapi_resource.shared_action_group["ops"].id },
    ]
    error_message = "An alert should notify its own action group and every shared action group that targets all alerts."
  }

  assert {
    condition     = length(azapi_resource.service_health_alert["service_health_security"].body.properties.actions.actionGroups) == 2
    error_message = "The security alert should notify the ops and security shared action groups."
  }

  assert {
    condition     = toset(keys(azapi_resource.lock_shared_action_group)) == toset(["ops", "security"])
    error_message = "Every shared action group should be locked."
  }

  assert {
    condition     = output.shared_action_group_resource_ids == { for key, action_group in azapi_resource.shared_action_group : key => action_group.id }
    error_message = "The shared action group output should list the shared action groups."
  }
}

run "shared_action_group_unknown_alert_key" {
  command = plan

  variables {
    shared_action_groups = {
      ops = {
        service_health_alert_keys = ["not_an_alert"]
      }
    }
  }

  expect_failures = [var.shared_action_groups]
}

run "shared_action_group_missing_secret" {
  command = plan

  variables {
    shared_action_groups = {
      ops = {
        webhook_receivers = [
          {
            name = "hook"
          }
        ]
      }
    }
  }

  expect_failures = [azapi_resource.shared_action_group]
}

run "shared_action_group_secret_for_unknown_group" {
  command = plan

  variables {
    shared_action_group_receiver_secrets = {
      not_a_group = {
        webhook_receiver_service_uris = {
          hook = "https://example.com/hook"
        }
      }
    }
  }

  expect_failures = [var.shared_action_group_receiver_secrets]
}

run "resource_group_name_trailing_period" {
  command = plan

  variables {
    resource_group_name = "rg-invalid."
  }

  expect_failures = [var.resource_group_name]
}

run "alert_name_trailing_period" {
  command = plan

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        name                 = "incident-alert."
      }
    }
  }

  expect_failures = [var.service_health_alerts]
}

run "receiver_names_duplicated_across_types" {
  command = plan

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          email_receivers = [{ name = "ops", email_address = "ops@example.com" }]
          sms_receivers   = [{ name = "ops", country_code = "1", phone_number = "5555550100" }]
        }
      }
    }
  }

  expect_failures = [var.service_health_alerts]
}

run "shared_receiver_names_duplicated_across_types" {
  command = plan

  variables {
    shared_action_groups = {
      ops = {
        email_receivers = [{ name = "ops", email_address = "ops@example.com" }]
        voice_receivers = [{ name = "ops", country_code = "1", phone_number = "5555550100" }]
      }
    }
  }

  expect_failures = [var.shared_action_groups]
}

run "action_group_names_collide_case_insensitively" {
  command = plan

  variables {
    shared_action_groups = {
      ops = {}
    }
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          name = "AG-OPS"
        }
      }
    }
  }

  expect_failures = [azapi_resource.action_group, azapi_resource.shared_action_group]
}

run "action_group_name_invalid" {
  command = plan

  variables {
    shared_action_groups = {
      "ops." = {}
    }
  }

  expect_failures = [azapi_resource.shared_action_group]
}

run "dedicated_action_group_names_collide_case_insensitively" {
  command = plan

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          name = "ag-service-health"
        }
      }
      maintenance = {
        service_health_alert = "Service Health Maintenance"
        action_group = {
          name = "AG-Service-Health"
        }
      }
    }
  }

  expect_failures = [azapi_resource.action_group]
}

run "alert_with_more_than_five_action_groups" {
  command = plan

  variables {
    shared_action_groups = {
      one   = {}
      two   = {}
      three = {}
      four  = {}
      five  = {}
    }
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          email_receivers = [{ name = "ops", email_address = "ops@example.com" }]
        }
      }
    }
  }

  expect_failures = [azapi_resource.service_health_alert]
}

run "alert_with_five_action_groups" {
  command = plan

  variables {
    shared_action_groups = {
      one   = {}
      two   = {}
      three = {}
      four  = {}
    }
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          email_receivers = [{ name = "ops", email_address = "ops@example.com" }]
        }
      }
    }
  }

  assert {
    condition     = length(azapi_resource.service_health_alert["incident"].body.properties.actions.actionGroups) == 5
    error_message = "Five action groups per alert should be accepted."
  }
}

run "secure_webhook_without_object_id" {
  command = plan

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          webhook_receivers = [{ name = "secure-hook", use_aad_auth = true }]
        }
      }
    }
  }

  expect_failures = [var.service_health_alerts]
}

run "shared_secure_webhook_without_object_id" {
  command = plan

  variables {
    shared_action_groups = {
      ops = {
        webhook_receivers = [{ name = "secure-hook", use_aad_auth = true }]
      }
    }
  }

  expect_failures = [var.shared_action_groups]
}

run "existing_action_group_ignores_other_attributes" {
  command = plan

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          existing_action_group = {
            resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.Insights/actionGroups/ag-shared"
          }
          group_short_name    = "longer-than-twelve"
          logic_app_receivers = [{ name = "logic", logic_app_resource_id = "not-a-resource-id" }]
          webhook_receivers   = [{ name = "secure-hook", use_aad_auth = true }]
        }
      }
    }
  }

  assert {
    condition     = length(azapi_resource.action_group) == 0
    error_message = "Attributes ignored because of existing_action_group should not fail validation."
  }
}
