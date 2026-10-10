# RMFR7 (minimum required outputs) applies to resource modules. This pattern module deploys a
# collection of alerts and action groups with no single primary resource, so it exposes
# discrete resource ID outputs instead of `resource_id`.
rule "avm_output_resource_id_required" {
  enabled = false
}
