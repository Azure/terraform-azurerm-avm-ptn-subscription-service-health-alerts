resource "terraform_data" "validation" {
  lifecycle {
    precondition {
      condition     = alltrue(values(local.action_group_name_valid))
      error_message = "Action group names must be 1-260 characters, must not contain `:<>*+/&%\\?|` or control characters, and must not end with a space or period."
    }
    precondition {
      condition     = alltrue(values(local.action_group_name_unique))
      error_message = "Names must be unique, case-insensitively, across every dedicated and shared action group created by the module."
    }
    precondition {
      condition     = alltrue(values(local.action_group_receiver_secrets_valid))
      error_message = "Receiver secrets must provide exactly one URL for each Function, Logic App and webhook receiver, keyed by receiver name. Automation webhook URIs may only refer to configured runbook receivers."
    }
    precondition {
      condition = alltrue([
        for key, alert in var.service_health_alerts :
        (alert.action_group == null ? 0 : 1) + length([
          for shared in values(var.shared_action_groups) : shared
          if shared.service_health_alert_keys == null ? true : contains(shared.service_health_alert_keys, key)
        ]) <= 5
      ])
      error_message = "Each alert can notify at most five action groups, including its dedicated or existing group and the shared groups that target it."
    }
  }
}

module "action_group" {
  source   = "git::https://github.com/Azure/terraform-azurerm-avm-res-insights-actiongroup.git?ref=3c72ad53fd37d860705030b718669dfd495a5269"
  for_each = local.action_group_configs

  location                     = "global"
  name                         = each.value.name
  parent_id                    = var.parent_id
  short_name                   = each.value.group_short_name
  arm_role_receivers           = local.action_group_receivers[each.key].arm_role_receivers
  automation_runbook_receivers = local.action_group_receivers[each.key].automation_runbook_receivers
  azure_app_push_receivers     = local.action_group_receivers[each.key].azure_app_push_receivers
  azure_function_receivers     = local.action_group_receivers[each.key].azure_function_receivers
  email_receivers              = local.action_group_receivers[each.key].email_receivers
  enable_telemetry             = var.enable_telemetry
  enabled                      = each.value.receivers.enabled
  event_hub_receivers          = local.action_group_receivers[each.key].event_hub_receivers
  ignore_body_changes          = var.ignore_body_changes.insights_action_groups
  itsm_receivers               = local.action_group_receivers[each.key].itsm_receivers
  lock                         = var.lock
  logic_app_receivers          = local.action_group_receivers[each.key].logic_app_receivers
  resource_types               = var.resource_types.insights_action_groups
  retry                        = var.retry
  sms_receivers                = local.action_group_receivers[each.key].sms_receivers
  tags                         = var.tags
  timeouts                     = var.timeouts
  voice_receivers              = local.action_group_receivers[each.key].voice_receivers
  webhook_receivers            = local.action_group_receivers[each.key].webhook_receivers

  depends_on = [terraform_data.validation]
}

resource "azapi_resource" "service_health_alert" {
  for_each = var.service_health_alerts

  location  = "global"
  name      = local.service_health_alert_names[each.key]
  parent_id = var.parent_id
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

  depends_on = [terraform_data.validation]
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
