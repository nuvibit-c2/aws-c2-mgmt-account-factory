output "default_region" {
  description = "The default region name"
  value       = local.default_region
}

output "account_id" {
  description = "The current account id"
  value       = local.current_account_id
}

output "aws_partition" {
  description = "The current AWS partition"
  value       = local.current_partition
}

output "ntc_parameters" {
  description = "Map of all ntc parameters"
  value       = local.ntc_parameters
}

output "ntc_account_factory_list" {
  description = "Account Factory account list"
  value = [
    for account in local.account_factory_list_enriched : account
    if try(account.account_tags["AccountDecommission"], false) == false
  ]
}