terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    # tflint-ignore: terraform_unused_required_providers
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
  }
}
