# Complete example

This deploys the module into an existing resource group and exercises its optional inputs:

- `resource_group_creation_enabled = false` with a resource group and a shared action group created by the example itself.
- A subset of alert types with custom names, descriptions and a disabled resource health alert.
- An action group created by the module with email and webhook receivers, and alerts that reuse the existing shared action group. The webhook service URI is passed through the sensitive `service_health_alert_receiver_secrets` variable.
- A `CanNotDelete` lock on every alert and on the created action group, tags, `retry` and `timeouts`.

This example requires Terraform 1.11 or later because it supplies a receiver secret. The receivers use `example.com` addresses, which cannot receive mail. Replace them before using this configuration outside a test subscription.
