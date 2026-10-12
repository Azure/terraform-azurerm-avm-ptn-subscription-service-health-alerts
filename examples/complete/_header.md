# Complete example

This deploys the module into an existing resource group and exercises its optional inputs:

- An existing resource group supplied through `parent_id`, with that resource group and an existing action group created by the example itself.
- A subset of alert types with custom names, descriptions and a disabled resource health alert.
- A dedicated action group for the incident alert, with email and webhook receivers. The webhook service URI is passed through the sensitive `service_health_alert_receiver_secrets` variable.
- A shared action group with two email receivers, notified by the incident, advisory and security alerts.
- An existing action group, created by the example, notified by the maintenance alert.
- A `CanNotDelete` lock on every alert and on both action groups created by the module, tags, `retry` and `timeouts`.

This example requires Terraform 1.11 or later because it supplies a receiver secret. All action groups are disabled, and email recipients use the reserved `.invalid` domain. The webhook uses the reserved `example.com` documentation domain because Azure rejects non-resolving webhook URLs even on disabled action groups. Replace the placeholder destinations before enabling notifications. Authenticate to a non-production subscription before running it.
