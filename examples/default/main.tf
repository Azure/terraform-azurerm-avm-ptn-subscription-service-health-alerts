provider "azapi" {}

resource "random_string" "suffix" {
  length  = 6
  numeric = true
  special = false
  upper   = false
}

module "test" {
  source = "../../"

  location            = var.location
  enable_telemetry    = var.enable_telemetry
  resource_group_name = "rg-asha-${random_string.suffix.result}"
}
