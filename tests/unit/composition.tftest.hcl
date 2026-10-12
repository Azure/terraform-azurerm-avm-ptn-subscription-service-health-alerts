mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000001"
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

override_resource {
  target = module.action_group["alert/incident"].azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/actionGroups/dedicated"
  }
}

override_resource {
  target = module.action_group["shared/ops"].azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/actionGroups/shared"
  }
}

run "real_module_composition_with_mocked_providers" {
  command = apply

  variables {
    location         = "swedencentral"
    parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
    enable_telemetry = false
    lock             = { kind = "CanNotDelete", name = "pattern-lock", notes = "Test lock." }
    tags             = { environment = "test" }
    retry = {
      error_message_regex  = ["ScopeLocked"]
      interval_seconds     = 15
      max_interval_seconds = 60
    }
    timeouts = { create = "30m", delete = "30m" }
    resource_types = {
      insights_action_groups = {
        insights_action_groups = "Microsoft.Insights/actionGroups@2023-01-01"
      }
      insights_activity_log_alerts = "Microsoft.Insights/activityLogAlerts@2020-10-01"
    }
    ignore_body_changes = {
      insights_action_groups = {
        insights_action_groups = ["properties.enabled"]
      }
      insights_activity_log_alerts = ["properties.description"]
    }
    service_health_alerts = {
      incident = {
        service_health_alert = "Service Health Incident"
        action_group = {
          enabled = false
          webhook_receivers = [
            { name = "z-last" },
            { name = "a-first" },
          ]
        }
      }
      resource_health = {
        service_health_alert = "Resource Health Unhealthy"
      }
    }
    service_health_alert_receiver_secrets = {
      incident = {
        webhook_receiver_service_uris = {
          a-first = "https://example.invalid/a?token=test-first"
          z-last  = "https://example.invalid/z?token=test-last"
        }
      }
    }
    shared_action_groups = {
      ops = {
        enabled         = false
        email_receivers = [{ name = "ops", email_address = "ops@example.invalid" }]
      }
    }
  }

  assert {
    condition     = output.action_group_resource_ids["incident"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/actionGroups/dedicated"
    error_message = "The pattern must return the real action-group module's computed output."
  }
  assert {
    condition     = output.shared_action_group_resource_ids["ops"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/actionGroups/shared"
    error_message = "Shared group outputs must be routed separately from dedicated groups."
  }
  assert {
    condition = local.alert_action_group_resource_ids["incident"] == [
      output.action_group_resource_ids["incident"],
      output.shared_action_group_resource_ids["ops"],
    ]
    error_message = "The alert module must receive both computed group IDs."
  }
  assert {
    condition     = toset(keys(output.service_health_alert_resource_ids)) == toset(["incident", "resource_health"])
    error_message = "Both leaf-only and nested any-of condition trees must work with the resource-module interface."
  }
}
