data "azapi_client_config" "current" {}

resource "azapi_resource" "resource_group" {
  count = var.resource_group_creation_enabled ? 1 : 0

  location               = var.location
  name                   = local.resource_group_name
  parent_id              = local.subscription_resource_id
  type                   = var.resource_types.resources_resource_groups
  body                   = {}
  ignore_body_changes    = length(var.ignore_body_changes.resources_resource_groups) > 0 ? var.ignore_body_changes.resources_resource_groups : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "action_group" {
  for_each = local.alert_action_groups

  location               = "global"
  name                   = local.action_group_configs[each.value].name
  parent_id              = local.resource_group_resource_id
  type                   = var.resource_types.insights_action_groups
  body                   = local.action_group_bodies[each.value]
  ignore_body_changes    = length(var.ignore_body_changes.insights_action_groups) > 0 ? var.ignore_body_changes.insights_action_groups : null
  response_export_values = []
  retry                  = var.retry
  sensitive_body         = lookup(local.action_group_sensitive_bodies, each.value, null)
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    precondition {
      condition     = local.action_group_name_valid[each.value]
      error_message = "The action group name `${local.action_group_configs[each.value].name}` of `service_health_alerts[\"${each.key}\"].action_group` must be 1-260 characters, must not contain `:<>+/&%\\?|` or control characters, and must not end with a space or period."
    }
    precondition {
      condition     = local.action_group_name_unique[each.value]
      error_message = "The action group name `${local.action_group_configs[each.value].name}` of `service_health_alerts[\"${each.key}\"].action_group` is used by more than one action group created by this module. Names are compared case-insensitively."
    }
    precondition {
      condition     = local.action_group_receiver_secrets_valid[each.value]
      error_message = "`service_health_alert_receiver_secrets[\"${each.key}\"]` must contain exactly one URL per Azure Function, Logic App and webhook receiver of the action group, keyed by receiver name, and may only contain automation runbook URIs for existing automation runbook receivers."
    }
  }
}

resource "azapi_resource" "shared_action_group" {
  for_each = var.shared_action_groups

  location               = "global"
  name                   = local.action_group_configs["shared/${each.key}"].name
  parent_id              = local.resource_group_resource_id
  type                   = var.resource_types.insights_action_groups
  body                   = local.action_group_bodies["shared/${each.key}"]
  ignore_body_changes    = length(var.ignore_body_changes.insights_action_groups) > 0 ? var.ignore_body_changes.insights_action_groups : null
  response_export_values = []
  retry                  = var.retry
  sensitive_body         = lookup(local.action_group_sensitive_bodies, "shared/${each.key}", null)
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  lifecycle {
    precondition {
      condition     = local.action_group_name_valid["shared/${each.key}"]
      error_message = "The action group name `${local.action_group_configs["shared/${each.key}"].name}` of `shared_action_groups[\"${each.key}\"]` must be 1-260 characters, must not contain `:<>+/&%\\?|` or control characters, and must not end with a space or period."
    }
    precondition {
      condition     = local.action_group_name_unique["shared/${each.key}"]
      error_message = "The action group name `${local.action_group_configs["shared/${each.key}"].name}` of `shared_action_groups[\"${each.key}\"]` is used by more than one action group created by this module. Names are compared case-insensitively."
    }
    precondition {
      condition     = local.action_group_receiver_secrets_valid["shared/${each.key}"]
      error_message = "`shared_action_group_receiver_secrets[\"${each.key}\"]` must contain exactly one URL per Azure Function, Logic App and webhook receiver of the action group, keyed by receiver name, and may only contain automation runbook URIs for existing automation runbook receivers."
    }
  }
}

resource "azapi_resource" "service_health_alert" {
  for_each = var.service_health_alerts

  location  = "global"
  name      = local.service_health_alert_names[each.key]
  parent_id = local.resource_group_resource_id
  type      = var.resource_types.insights_activity_log_alerts
  body = {
    properties = {
      scopes = [local.subscription_resource_id]
      condition = {
        allOf = local.service_health_alert_conditions[each.value.service_health_alert]
      }
      actions = {
        actionGroups = [
          for action_group_resource_id in local.alert_action_group_resource_ids[each.key] : {
            actionGroupId = action_group_resource_id
          }
        ]
      }
      enabled     = each.value.enabled
      description = coalesce(each.value.description, local.service_health_alert_descriptions[each.value.service_health_alert])
    }
  }
  ignore_body_changes    = length(var.ignore_body_changes.insights_activity_log_alerts) > 0 ? var.ignore_body_changes.insights_activity_log_alerts : null
  response_export_values = []
  retry                  = var.retry
  tags                   = var.tags

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "lock_action_group" {
  for_each = var.lock == null ? toset([]) : toset(keys(local.alert_action_groups))

  name                   = local.lock.name
  parent_id              = azapi_resource.action_group[each.key].id
  type                   = var.resource_types.authorization_locks
  body                   = local.lock.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "lock_shared_action_group" {
  for_each = var.lock == null ? toset([]) : toset(keys(var.shared_action_groups))

  name                   = local.lock.name
  parent_id              = azapi_resource.shared_action_group[each.key].id
  type                   = var.resource_types.authorization_locks
  body                   = local.lock.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "lock_service_health_alert" {
  for_each = var.lock == null ? toset([]) : toset(keys(var.service_health_alerts))

  name                   = local.lock.name
  parent_id              = azapi_resource.service_health_alert[each.key].id
  type                   = var.resource_types.authorization_locks
  body                   = local.lock.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

resource "azapi_resource" "lock_resource_group" {
  count = var.lock != null && var.resource_group_creation_enabled ? 1 : 0

  name                   = local.lock.name
  parent_id              = azapi_resource.resource_group[0].id
  type                   = var.resource_types.authorization_locks
  body                   = local.lock.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]

    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }

  depends_on = [
    azapi_resource.action_group,
    azapi_resource.lock_action_group,
    azapi_resource.lock_service_health_alert,
    azapi_resource.lock_shared_action_group,
    azapi_resource.service_health_alert,
    azapi_resource.shared_action_group,
  ]
}
