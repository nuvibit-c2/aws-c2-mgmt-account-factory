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

output "ntc_account_factory_list" {
  description = "Account Factory account list"
  value = [
    for account in local.account_factory_list_enriched : account
    if try(account.account_tags["AccountDecommission"], false) == false
  ]
}