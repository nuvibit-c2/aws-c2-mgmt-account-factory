/*
NTC Account Factory will inject the following input vars inside the Terraform account baseline:

var.current_region (string)
var.main_region (string)
var.is_current_region_main_region (bool)
var.current_account_id (string)
var.current_account_name (string)
var.current_account_email (string)
var.current_account_ou_path (string)
var.current_account_tags (map)
var.current_account_alternate_contacts (list)
var.current_account_customer_values (any)

These variables can be used inside the terraform baseline contents to decide which resources should only be deployed in a single region.

EXAMPLE: 
The same IAM role cannot be created in each region because IAM is a global service.
Instead the IAM role should only be created in the main region and in every other region a data source should be used to get the role ARN.
*/

# ---------------------------------------------------------------------------------------------------------------------
# § LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  ntc_parameters = try(module.ntc_parameters_reader.all_parameters[0], {})
}

# ---------------------------------------------------------------------------------------------------------------------
# § Private Module from Terraform Registry - requires 'account_baseline_terraform_registry_token' & 'account_baseline_terraform_registry_host'
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader" {
  source  = "spacelift.io/nuvibit/ntc-parameters/aws//modules/reader"
  version = "1.1.2"

  count = var.is_current_region_main_region ? 1 : 0

  bucket_name = "aws-c2-ntc-parameters"
}

# ---------------------------------------------------------------------------------------------------------------------
# § SUBDOMAIN DELEGATION - ASSUME ROLE - CONNECTIVITY ACCOUNT
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_r53_records" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-route53//modules/records?ref=feat-update-records"
  # source  = "spacelift.io/nuvibit/ntc-route53/aws//modules/records"
  # version = "1.1.2"

  # apply this module only for account 'aws-c2-ares-dev'
  count = alltrue([
    var.current_account_name == "aws-c2-ares-dev",
    var.is_current_region_main_region
  ]) ? 1 : 0

  zone_name = "nuvibit.dev"
  zone_type = "public"
  zone_delegation_list = [
    {
      subdomain_zone_name = "ares-dev"
      subdomain_nameserver_list = [
        "ns-1124.awsdns-12.org.",
        "ns-1854.awsdns-39.co.uk.",
        "ns-807.awsdns-36.net.",
        "ns-476.awsdns-59.com.",
      ]
      dnssec_enabled   = true
      dnssec_ds_record = "26175 13 2 447B4A317DAEC3A213AB156BE09A25E363DDE10903B666B3A2301ECFB3C5C931"
    }
  ]

  # 'aws.connectivity' configuration_alias was dynamically generated with 'baseline_assume_role_providers'
  providers = {
    aws = aws.connectivity
  }
}