mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id          = "00000000-0000-0000-0000-000000000000"
      tenant_id                = "00000000-0000-0000-0000-000000000001"
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/activityLogAlerts/mock"
    }
  }
}

mock_provider "modtm" {}

mock_provider "random" {}

override_module {
  target = module.action_group
  outputs = {
    resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/actionGroups/mock"
  }
}

variables {
  location  = "swedencentral"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
}

run "defaults" {
  command = apply

  variables {
    enable_telemetry = true
  }

  assert {
    condition     = toset(keys(output.service_health_alert_resource_ids)) == toset(["resource_health_unhealthy", "service_health_advisory", "service_health_incident", "service_health_maintenance", "service_health_security"])
    error_message = "The five default alert types must be created."
  }
  assert {
    condition     = local.subscription_resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "The monitored subscription must come from parent_id."
  }
  assert {
    condition     = local.service_health_alert_names["service_health_incident"] == "ServiceHealthIncidentAlert" && local.service_health_alert_names["resource_health_unhealthy"] == "ResourceHealthUnhealthyAlert"
    error_message = "Default names must be derived from the alert type."
  }
  assert {
    condition = local.service_health_alert_conditions["Service Health Incident"] == [
      { field = "category", equals = "ServiceHealth" },
      { field = "properties.incidentType", equals = "Incident" },
    ]
    error_message = "Incident alerts must match the ServiceHealth category and Incident type."
  }
  assert {
    condition = alltrue([
      local.service_health_alert_conditions["Service Health Advisory"][1].equals == "ActionRequired",
      local.service_health_alert_conditions["Service Health Maintenance"][1].equals == "Maintenance",
      local.service_health_alert_conditions["Service Health Security"][1].equals == "Security",
      local.service_health_alert_conditions["Resource Health Unhealthy"][0].equals == "ResourceHealth",
    ])
    error_message = "Each alert must retain its intended category and incident type."
  }
  assert {
    condition = local.service_health_alert_conditions["Resource Health Unhealthy"][1].any_of == [
      { field = "properties.cause", equals = "PlatformInitiated" },
      { field = "properties.cause", equals = "UserInitiated" },
      ] && local.service_health_alert_conditions["Resource Health Unhealthy"][2].any_of == [
      { field = "properties.currentHealthStatus", equals = "Degraded" },
      { field = "properties.currentHealthStatus", equals = "Unavailable" },
    ]
    error_message = "Resource health alerts must match both supported causes and unhealthy statuses."
  }
  assert {
    condition     = output.action_group_resource_ids == {} && output.shared_action_group_resource_ids == {} && alltrue([for ids in values(local.alert_action_group_resource_ids) : length(ids) == 0])
    error_message = "Defaults must create no action groups or notification destinations."
  }
  assert {
    condition     = length(azapi_resource.telemetry) == 1
    error_message = "Telemetry must be created when enabled."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "subscription_from_existing_parent" {
  command = apply

  variables {
    parent_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/existing-rg"
  }

  assert {
    condition     = local.subscription_resource_id == "/subscriptions/11111111-1111-1111-1111-111111111111"
    error_message = "An explicitly supplied parent must determine the monitored subscription, not the provider's active subscription."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "dedicated_existing_and_shared_groups" {
  command = apply

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          email_receivers = [{ name = "incident", email_address = "incident@example.invalid" }]
        }
      }
      maintenance = {
        service_health_alert = "Service Health Maintenance"
        name                 = "planned-maintenance"
        description          = "Planned maintenance."
        enabled              = false
        action_group = {
          existing_action_group = {
            resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/existing/providers/Microsoft.Insights/actionGroups/existing"
          }
          group_short_name    = "ignored-even-when-too-long"
          logic_app_receivers = [{ name = "ignored", logic_app_resource_id = "ignored" }]
        }
      }
      security = {
        service_health_alert = "Service Health Security"
      }
      resource_health = {
        service_health_alert = "Resource Health Unhealthy"
      }
    }
    shared_action_groups = {
      incident = {
        service_health_alert_keys = ["incident", "security"]
        enabled                   = false
        email_receivers = [
          { name = "ops", email_address = "ops@example.invalid" },
          { name = "oncall", email_address = "oncall@example.invalid", use_common_alert_schema = true },
        ]
      }
      all = {
        name             = "ag-every-alert"
        group_short_name = "all"
      }
    }
  }

  assert {
    condition     = toset(keys(local.action_group_configs)) == toset(["alert/incident", "shared/incident", "shared/all"])
    error_message = "Dedicated and shared groups with the same caller key must remain distinct; existing groups must not be recreated."
  }
  assert {
    condition     = local.action_group_configs["alert/incident"].name == "ServiceHealthIncidentAlert-action-group" && local.action_group_configs["alert/incident"].group_short_name == "ServiceHealt"
    error_message = "Dedicated group name and short name must retain their defaults."
  }
  assert {
    condition     = local.action_group_configs["shared/incident"].name == "ag-incident" && local.action_group_configs["shared/all"].group_short_name == "all"
    error_message = "Shared group defaults and explicit short names must be retained."
  }
  assert {
    condition     = length(local.action_group_receivers["shared/incident"].email_receivers) == 2 && local.action_group_configs["shared/incident"].receivers.enabled == false
    error_message = "Shared receivers and the disabled flag must be passed to the resource module."
  }
  assert {
    condition     = length(local.alert_action_group_resource_ids["incident"]) == 3 && length(local.alert_action_group_resource_ids["security"]) == 2 && length(local.alert_action_group_resource_ids["resource_health"]) == 1
    error_message = "Shared group targeting must combine with dedicated groups without notifying unrelated alerts."
  }
  assert {
    condition     = local.alert_action_group_resource_ids["maintenance"][0] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/existing/providers/Microsoft.Insights/actionGroups/existing"
    error_message = "An existing action group must remain linked by its supplied resource ID."
  }
  assert {
    condition     = toset(keys(output.action_group_resource_ids)) == toset(["incident"]) && toset(keys(output.shared_action_group_resource_ids)) == toset(["incident", "all"])
    error_message = "Outputs must keep caller keys and exclude existing action groups."
  }
  assert {
    condition     = local.service_health_alert_names["maintenance"] == "planned-maintenance"
    error_message = "Explicit alert names must be retained."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "receiver_mapping_and_secret_order" {
  command = apply

  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          arm_role_receivers = [{ name = "owners", role_id = "8e3af657-a8ff-443c-a75c-2fe8c4bcb635", use_common_alert_schema = true }]
          automation_runbook_receivers = [{
            name                           = "runbook"
            automation_account_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Automation/automationAccounts/aa"
            is_global_runbook              = false
            runbook_name                   = "restart"
            webhook_resource_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Automation/automationAccounts/aa/webhooks/wh"
          }]
          azure_app_push_receivers = [{ name = "app", email_address = "app@example.invalid" }]
          azure_function_receivers = [{
            name                     = "function"
            function_app_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Web/sites/fa"
            function_name            = "notify"
          }]
          email_receivers = [{ name = "email", email_address = "email@example.invalid" }]
          event_hub_receivers = [{
            name                = "events"
            event_hub_namespace = "events"
            event_hub_name      = "alerts"
            subscription_id     = "00000000-0000-0000-0000-000000000000"
          }]
          itsm_receivers = [{
            name                 = "itsm"
            connection_id        = "connection"
            region               = "westeurope"
            ticket_configuration = "{}"
            workspace_id         = "workspace"
          }]
          logic_app_receivers = [{
            name                  = "logic"
            logic_app_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Logic/workflows/la"
          }]
          sms_receivers     = [{ name = "sms", country_code = "1", phone_number = "5555550100" }]
          voice_receivers   = [{ name = "voice", country_code = "1", phone_number = "5555550101" }]
          webhook_receivers = [{ name = "z-last" }, { name = "a-first" }]
        }
      }
    }
    service_health_alert_receiver_secrets = {
      incident = {
        automation_runbook_receiver_service_uris  = { runbook = "https://example.invalid/runbook?token=test" }
        azure_function_receiver_http_trigger_urls = { function = "https://example.invalid/function?code=test" }
        logic_app_receiver_callback_urls          = { logic = "https://example.invalid/logic?sig=test" }
        webhook_receiver_service_uris = {
          a-first = "https://example.invalid/a?token=first"
          z-last  = "https://example.invalid/z?token=last"
        }
      }
    }
  }

  assert {
    condition     = length(local.action_group_receivers["alert/incident"]) == 11 && local.action_group_receivers["alert/incident"].arm_role_receivers["0"].use_common_alert_schema
    error_message = "All eleven receiver types and their common-schema flags must be mapped."
  }
  assert {
    condition     = local.action_group_receivers["alert/incident"].automation_runbook_receivers["0"].automation_account_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Automation/automationAccounts/aa"
    error_message = "The Automation account ID must use the resource module's input name."
  }
  assert {
    condition     = local.action_group_receivers["alert/incident"].logic_app_receivers["0"].resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Logic/workflows/la"
    error_message = "The Logic App resource ID must use the resource module's input name."
  }
  assert {
    condition = nonsensitive(
      local.action_group_receivers["alert/incident"].webhook_receivers["0"].service_uri == "https://example.invalid/z?token=last" &&
      local.action_group_receivers["alert/incident"].webhook_receivers["1"].service_uri == "https://example.invalid/a?token=first" &&
      local.action_group_receivers["alert/incident"].azure_function_receivers["0"].http_trigger_url == "https://example.invalid/function?code=test" &&
      local.action_group_receivers["alert/incident"].logic_app_receivers["0"].callback_url == "https://example.invalid/logic?sig=test"
    )
    error_message = "Each secret must remain attached to the receiver named by the caller, regardless of list or map ordering."
  }
  assert {
    condition     = issensitive(local.action_group_receivers["alert/incident"].webhook_receivers["0"].service_uri) && issensitive(local.action_group_receivers["alert/incident"].automation_runbook_receivers["0"].service_uri)
    error_message = "Receiver URLs must remain sensitive while crossing the module boundary."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "shared_receiver_secret_mapping" {
  command = apply

  variables {
    shared_action_groups = {
      ops = { webhook_receivers = [{ name = "hook" }] }
    }
    shared_action_group_receiver_secrets = {
      ops = { webhook_receiver_service_uris = { hook = "https://example.invalid/shared" } }
    }
  }

  assert {
    condition     = nonsensitive(local.action_group_receivers["shared/ops"].webhook_receivers["0"].service_uri) == "https://example.invalid/shared"
    error_message = "Shared receiver URLs must use the shared secret map."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "no_alerts_and_telemetry_disabled" {
  command = apply

  variables {
    service_health_alerts = {}
    enable_telemetry      = false
  }

  assert {
    condition     = output.service_health_alert_resource_ids == {} && output.action_group_resource_ids == {} && output.shared_action_group_resource_ids == {}
    error_message = "Empty collections must create no alerts or action groups."
  }
  assert {
    condition     = length(azapi_resource.telemetry) == 0
    error_message = "The telemetry opt-out must be respected."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "invalid_parent_id" {
  command = plan
  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }
  expect_failures = [var.parent_id]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "invalid_service_health_alert" {
  command = plan
  variables {
    service_health_alerts = { invalid = { service_health_alert = "Service Health Outage" } }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "invalid_alert_name" {
  command = plan
  variables {
    service_health_alerts = { incident = { service_health_alert = "Service Health Incident", name = "has spaces" } }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "alert_name_trailing_period" {
  command = plan
  variables {
    service_health_alerts = { incident = { service_health_alert = "Service Health Incident", name = "incident." } }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "duplicate_alert_names" {
  command = plan
  variables {
    service_health_alerts = {
      one = { service_health_alert = "Service Health Incident" }
      two = { service_health_alert = "Service Health Incident" }
    }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "group_short_name_too_long" {
  command = plan
  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group         = { group_short_name = "thirteenchars" }
      }
    }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "shared_group_short_name_too_long" {
  command = plan
  variables {
    shared_action_groups = { ops = { group_short_name = "thirteenchars" } }
  }
  expect_failures = [var.shared_action_groups]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "invalid_existing_group_id" {
  command = plan
  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group         = { existing_action_group = { resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet" } }
      }
    }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "invalid_logic_app_id" {
  command = plan
  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group         = { logic_app_receivers = [{ name = "logic", logic_app_resource_id = "invalid" }] }
      }
    }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "invalid_function_id" {
  command = plan
  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group         = { azure_function_receivers = [{ name = "function", function_app_resource_id = "invalid", function_name = "notify" }] }
      }
    }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "invalid_lock" {
  command = plan
  variables {
    lock = { kind = "None" }
  }
  expect_failures = [var.lock]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "missing_receiver_secret" {
  command = plan
  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group         = { webhook_receivers = [{ name = "hook" }] }
      }
    }
  }
  expect_failures = [terraform_data.validation]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "unknown_receiver_secret" {
  command = plan
  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group         = { webhook_receivers = [{ name = "hook" }] }
      }
    }
    service_health_alert_receiver_secrets = {
      incident = { webhook_receiver_service_uris = { hook = "https://example.invalid/hook", typo = "https://example.invalid/typo" } }
    }
  }
  expect_failures = [terraform_data.validation]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "unknown_alert_secret" {
  command = plan
  variables {
    service_health_alert_receiver_secrets = {
      unknown = { webhook_receiver_service_uris = { hook = "https://example.invalid/hook" } }
    }
  }
  expect_failures = [var.service_health_alert_receiver_secrets]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "duplicate_receiver_names" {
  command = plan
  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          webhook_receivers = [{ name = "hook" }, { name = "hook" }]
        }
      }
    }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "receiver_names_duplicated_across_types" {
  command = plan
  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          email_receivers = [{ name = "ops", email_address = "ops@example.invalid" }]
          sms_receivers   = [{ name = "ops", country_code = "1", phone_number = "5555550100" }]
        }
      }
    }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "shared_receiver_names_duplicated_across_types" {
  command = plan
  variables {
    shared_action_groups = {
      ops = {
        email_receivers = [{ name = "ops", email_address = "ops@example.invalid" }]
        voice_receivers = [{ name = "ops", country_code = "1", phone_number = "5555550100" }]
      }
    }
  }
  expect_failures = [var.shared_action_groups]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "shared_group_unknown_alert" {
  command = plan
  variables {
    shared_action_groups = { ops = { service_health_alert_keys = ["unknown"] } }
  }
  expect_failures = [var.shared_action_groups]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "shared_group_missing_secret" {
  command = plan
  variables {
    shared_action_groups = { ops = { webhook_receivers = [{ name = "hook" }] } }
  }
  expect_failures = [terraform_data.validation]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "shared_secret_unknown_group" {
  command = plan
  variables {
    shared_action_group_receiver_secrets = {
      unknown = { webhook_receiver_service_uris = { hook = "https://example.invalid/hook" } }
    }
  }
  expect_failures = [var.shared_action_group_receiver_secrets]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "group_names_collide_across_dedicated_and_shared" {
  command = plan
  variables {
    shared_action_groups = { ops = {} }
    service_health_alerts = {
      incident = { service_health_alert = "Service Health Incident", action_group = { name = "AG-OPS" } }
    }
  }
  expect_failures = [terraform_data.validation]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "dedicated_names_collide_case_insensitively" {
  command = plan
  variables {
    service_health_alerts = {
      incident    = { service_health_alert = "Service Health Incident", action_group = { name = "ag-service-health" } }
      maintenance = { service_health_alert = "Service Health Maintenance", action_group = { name = "AG-Service-Health" } }
    }
  }
  expect_failures = [terraform_data.validation]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "invalid_generated_group_name" {
  command = plan
  variables {
    shared_action_groups = { "ops." = {} }
  }
  expect_failures = [terraform_data.validation]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "invalid_group_name_asterisk" {
  command = plan
  variables {
    shared_action_groups = { ops = { name = "ag-*ops" } }
  }
  expect_failures = [terraform_data.validation]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "more_than_five_action_groups" {
  command = plan
  variables {
    shared_action_groups = { one = {}, two = {}, three = {}, four = {}, five = {} }
    service_health_alerts = {
      incident = { service_health_alert = "Service Health Incident", action_group = {} }
    }
  }
  expect_failures = [terraform_data.validation]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "exactly_five_action_groups" {
  command = apply
  variables {
    shared_action_groups = { one = {}, two = {}, three = {}, four = {} }
    service_health_alerts = {
      incident = { service_health_alert = "Service Health Incident", action_group = {} }
    }
  }
  assert {
    condition     = length(local.alert_action_group_resource_ids["incident"]) == 5
    error_message = "Exactly five action groups must remain supported."
  }
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "secure_webhook_without_object_id" {
  command = plan
  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group         = { webhook_receivers = [{ name = "secure", use_aad_auth = true }] }
      }
    }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "shared_secure_webhook_without_object_id" {
  command = plan
  variables {
    shared_action_groups = {
      ops = { webhook_receivers = [{ name = "secure", use_aad_auth = true }] }
    }
  }
  expect_failures = [var.shared_action_groups]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "empty_ignore_body_path" {
  command = plan
  variables {
    ignore_body_changes = {
      insights_action_groups = { insights_action_groups = [" "] }
    }
  }
  expect_failures = [var.ignore_body_changes]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "secure_webhook_without_identifier_uri" {
  command = plan
  variables {
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          webhook_receivers = [{ name = "secure", use_aad_auth = true, object_id = "00000000-0000-0000-0000-000000000001" }]
        }
      }
    }
  }
  expect_failures = [var.service_health_alerts]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}

run "shared_secure_webhook_blank_identifier_uri" {
  command = plan
  variables {
    shared_action_groups = {
      ops = {
        webhook_receivers = [{ name = "secure", use_aad_auth = true, object_id = "00000000-0000-0000-0000-000000000001", identifier_uri = " " }]
      }
    }
  }
  expect_failures = [var.shared_action_groups]
  providers = {
    azapi  = azapi
    modtm  = modtm
    random = random
  }
}
