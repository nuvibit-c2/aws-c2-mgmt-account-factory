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
  ntc_parameters_github   = module.ntc_parameters_reader_github.all_parameters
  ntc_parameters_ssh      = module.ntc_parameters_reader_ssh.all_parameters
  ntc_parameters_registry = module.ntc_parameters_reader_registry.all_parameters
}

# ---------------------------------------------------------------------------------------------------------------------
# § Private Module from Github with HTTPS - requires 'account_baseline_github_access_token'
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader_github" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=1.1.2"

  bucket_name = "nivel-ntc-parameters"
}

# ---------------------------------------------------------------------------------------------------------------------
# § Private Module from Git with SSH - requires 'account_baseline_git_ssh_key'
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader_ssh" {
  source = "git@github.com:nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=1.1.2"

  bucket_name = "nivel-ntc-parameters"
}

# ---------------------------------------------------------------------------------------------------------------------
# § Private Module from Terraform Registry - requires 'account_baseline_terraform_registry_token' & 'account_baseline_terraform_registry_host'
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader_registry" {
  source  = "spacelift.io/nuvibit/ntc-parameters/aws"
  version = "1.1.2"

  bucket_name = "nivel-ntc-parameters"
}
