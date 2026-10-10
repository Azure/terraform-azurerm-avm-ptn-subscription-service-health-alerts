# Default example

This deploys the module with its defaults: a resource group in the current subscription and one activity log alert for each supported service health and resource health alert type, without action groups.

The only inputs are the Azure CLI (or other AzAPI) credentials and the subscription selected in that context. A random suffix keeps the resource group name unique so the example does not collide with an existing `rg-asha-<subscription ID>` resource group.
