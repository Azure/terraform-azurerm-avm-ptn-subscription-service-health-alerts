# Complete example

This deploys the module into an existing resource group and exercises its optional inputs:

- `resource_group_creation_enabled = false` with a resource group and an action group created by the example itself.
- A subset of alert types with custom names, descriptions and a disabled resource health alert.
- A dedicated action group for the incident alert, with email and webhook receivers. The webhook service URI is passed through the sensitive `service_health_alert_receiver_secrets` variable.
- A shared action group with two email receivers, notified by the incident, advisory and security alerts.
- An existing action group, created by the example, notified by the maintenance alert.
- A `CanNotDelete` lock on every alert and on both action groups created by the module, tags, `retry` and `timeouts`.

This example requires Terraform 1.11 or later because it supplies a receiver secret. The receivers use `example.com` addresses, which cannot receive mail. Replace them before using this configuration outside a test subscription.
