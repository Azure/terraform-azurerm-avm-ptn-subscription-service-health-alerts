provider "azapi" {}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  numeric = true
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-asha-complete-${random_string.suffix.result}"
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type                   = "Microsoft.Resources/resourceGroups@2025-04-01"
  body                   = {}
  response_export_values = []
}

resource "azapi_resource" "existing_action_group" {
  location  = "global"
  name      = "ag-asha-existing-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Insights/actionGroups@2023-01-01"
  body = {
    properties = {
      groupShortName = "ashexisting"
      enabled        = true
      emailReceivers = [
        {
          name                 = "platform-team"
          emailAddress         = "platform-team@example.com"
          useCommonAlertSchema = true
        }
      ]
    }
  }
  response_export_values = []
}

module "test" {
  source = "../../"

  location         = var.location
  enable_telemetry = var.enable_telemetry
  lock = {
    kind = "CanNotDelete"
  }
  resource_group_creation_enabled = false
  resource_group_name             = azapi_resource.resource_group.name
  retry = {
    error_message_regex  = ["ScopeLocked"]
    interval_seconds     = 15
    max_interval_seconds = 60
  }
  service_health_alert_receiver_secrets = {
    incident = {
      webhook_receiver_service_uris = {
        incident-webhook = sensitive("https://example.com/service-health")
      }
    }
  }
  service_health_alerts = {
    incident = {
      service_health_alert = "Service Health Incident"
      description          = "Service issues affecting resources in this subscription."
      action_group = {
        name             = "ag-asha-incident-${random_string.suffix.result}"
        group_short_name = "ashincident"
        email_receivers = [
          {
            name                    = "on-call"
            email_address           = "on-call@example.com"
            use_common_alert_schema = true
          }
        ]
        webhook_receivers = [
          {
            name = "incident-webhook"
          }
        ]
      }
    }
    maintenance = {
      service_health_alert = "Service Health Maintenance"
      action_group = {
        existing_action_group = {
          resource_id = azapi_resource.existing_action_group.id
        }
      }
    }
    advisory = {
      service_health_alert = "Service Health Advisory"
    }
    security = {
      service_health_alert = "Service Health Security"
      name                 = "ServiceHealthSecurityAdvisoryAlert"
    }
    resource_health = {
      service_health_alert = "Resource Health Unhealthy"
      enabled              = false
    }
  }
  shared_action_groups = {
    platform = {
      name                      = "ag-asha-platform-${random_string.suffix.result}"
      group_short_name          = "ashplatform"
      service_health_alert_keys = ["incident", "advisory", "security"]
      email_receivers = [
        {
          name          = "platform-team"
          email_address = "platform-team@example.com"
        },
        {
          name                    = "platform-lead"
          email_address           = "platform-lead@example.com"
          use_common_alert_schema = true
        }
      ]
    }
  }
  subscription_id = data.azapi_client_config.current.subscription_id
  tags = {
    environment = "example"
    workload    = "service-health"
  }
  timeouts = {
    create = "30m"
    delete = "30m"
  }
}
