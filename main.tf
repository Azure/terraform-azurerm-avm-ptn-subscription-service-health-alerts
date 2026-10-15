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
  source    = "Azure/avm-res-insights-actiongroup/azurerm"
  version   = "0.1.0"
  providers = { modtm = modtm }
  for_each  = local.action_group_configs

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

module "service_health_alert" {
  source    = "Azure/avm-res-insights-activitylogalert/azurerm"
  version   = "0.1.0"
  providers = { modtm = modtm }
  for_each  = var.service_health_alerts

  condition = {
    all_of = local.service_health_alert_conditions[each.value.service_health_alert]
  }
  location  = var.location
  name      = local.service_health_alert_names[each.key]
  parent_id = var.parent_id
  scopes    = [local.subscription_resource_id]
  action_groups = {
    for index, resource_id in local.alert_action_group_resource_ids[each.key] : tostring(index) => {
      action_group_id = resource_id
    }
  }
  description         = coalesce(each.value.description, local.service_health_alert_descriptions[each.value.service_health_alert])
  enable_telemetry    = var.enable_telemetry
  enabled             = each.value.enabled
  ignore_body_changes = var.ignore_body_changes.insights_activity_log_alerts
  lock                = var.lock
  resource_location   = "global"
  resource_types      = var.resource_types.insights_activity_log_alerts
  retry               = var.retry
  tags                = var.tags
  timeouts            = var.timeouts

  depends_on = [terraform_data.validation]
}
