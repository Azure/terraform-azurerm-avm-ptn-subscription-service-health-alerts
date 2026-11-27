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
  name                   = "rg-asha-default-${random_string.suffix.result}"
  parent_id              = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  type                   = "Microsoft.Resources/resourceGroups@2025-04-01"
  body                   = {}
  response_export_values = []
}

module "test" {
  source = "../../"

  location         = var.location
  parent_id        = azapi_resource.resource_group.id
  enable_telemetry = var.enable_telemetry
}
