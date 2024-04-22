output "default_region" {
  description = "The default region name"
  value       = data.aws_region.default.name
}

output "account_id" {
  description = "The current account id"
  value       = data.aws_caller_identity.current.account_id
}

output "ntc_parameters" {
  description = "Map of all ntc parameters"
  value       = local.ntc_parameters
}

output "accounts_with_terraform_pipeline" {
  description = "List of accounts which require a terraform pipeline"
  value = [
    for account in local.account_factory_list_enriched : account
    if alltrue([
      account.customer_values.create_terraform_pipeline,
      account.account_tags["AccountDecommission"] == false,
    ])
  ]
}