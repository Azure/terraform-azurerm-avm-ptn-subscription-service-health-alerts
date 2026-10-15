terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    modtm = { "source" : "azure/modtm", "version" : "~\u003e 0.3" }
  }
}
