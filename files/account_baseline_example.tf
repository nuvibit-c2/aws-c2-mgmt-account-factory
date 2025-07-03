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
var.baseline_parameters (any)

These variables can be used inside the terraform baseline contents to decide which resources should only be deployed in a single region.

EXAMPLE: 
The same IAM role cannot be created in each region because IAM is a global service.
Instead the IAM role should only be created in the main region and in every other region a data source should be used to get the role ARN.
*/

# ---------------------------------------------------------------------------------------------------------------------
# § LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  ntc_parameters_github   = try(module.ntc_parameters_reader_github.all_parameters, {})
  ntc_parameters_ssh      = try(module.ntc_parameters_reader_ssh.all_parameters, {})
  ntc_parameters_registry = try(module.ntc_parameters_reader_registry.all_parameters, {})
}

# ---------------------------------------------------------------------------------------------------------------------
# § Private Module from Github with HTTPS - requires 'account_baseline_github_access_token'
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader_github" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=1.1.4"

  bucket_name = var.baseline_parameters["parameters_bucket_name"]
}

# ---------------------------------------------------------------------------------------------------------------------
# § Private Module from Git with SSH - requires 'account_baseline_git_ssh_key'
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader_ssh" {
  source = "git@github.com:nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=1.1.4"

  bucket_name = var.baseline_parameters["parameters_bucket_name"]
}

# ---------------------------------------------------------------------------------------------------------------------
# § Private Module from Terraform Registry - requires 'account_baseline_terraform_registry_token' & 'account_baseline_terraform_registry_host'
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader_registry" {
  source  = "spacelift.io/nuvibit/ntc-parameters/aws//modules/reader"
  version = "1.1.4"

  bucket_name = var.baseline_parameters["parameters_bucket_name"]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------
# WARNING: IAM is a global service and can only be created once in a single region
# ntc account baseline is intended to provision resources in multiple accounts and multiple regions
resource "aws_iam_role" "ntc_example_iam" {
  # this condition allows certain resources or modules to be only provisioned once
  count = var.is_current_region_main_region == true ? 1 : 0

  name               = var.baseline_parameters["example_iam_role_name"]
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.ntc_example_iam[0].json
}

data "aws_iam_policy_document" "ntc_example_iam" {
  # this condition allows certain resources or modules to be only provisioned once
  count = var.is_current_region_main_region == true ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [var.current_account_id]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ntc_example_iam" {
  # this condition allows certain resources or modules to be only provisioned once
  count = var.is_current_region_main_region == true ? 1 : 0

  role       = aws_iam_role.ntc_example_iam[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ CROSS ACCOUNT - TEST
# ---------------------------------------------------------------------------------------------------------------------
data "aws_route53_zones" "all" {
  provider = aws.connectivity
}