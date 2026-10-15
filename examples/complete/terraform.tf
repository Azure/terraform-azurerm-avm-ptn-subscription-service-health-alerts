terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    modtm = { "source" : "registry.terraform.io/azure/modtm", "version" : "~\u003e 0.3" }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
