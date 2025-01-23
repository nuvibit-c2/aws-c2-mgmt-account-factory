locals {
  ntc_parameters_bucket_name = "aws-c2-ntc-parameters"
  ntc_parameters_writer_node = "mgmt-account-factory"

  # parameters that are managed by account factory pipeline
  ntc_parameters_to_write = {
    "core_accounts"      = local.account_factory_core_account_ids
    "baseline_role_arns" = module.ntc_account_factory.account_factory_baseline_iam_role_arns
  }

  # by default existing node parameters will be merged with new parameters to avoid deleting parameters
  ntc_replace_parameters = true

  # node owner that is also the account factory can optionally store an account map
  ntc_store_account_map = true
  ntc_account_map = {
    for account in local.account_factory_list_enriched : account.account_id => account
  }

  # parameters are shared with parameter node owners by default and with the entire organization if org_id is specified
  share_parameters_with_entire_org = true

  # map of parameters merged from all parameter nodes
  ntc_parameters = module.ntc_parameters_reader.all_parameters
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - BUCKET (DEPLOY FIRST)
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_bucket" {
  # source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters?ref=1.1.2"
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters?ref=add-encryption-policy"

  force_destroy = false
  bucket_name   = local.ntc_parameters_bucket_name
  org_id        = local.share_parameters_with_entire_org ? data.aws_organizations_organization.current.id : ""
  # the ntc parameter bucket should ideally be created in same pipeline as account factory
  # all organization accounts are granted read permission for all parameters
  # only the parameter node owner account is granted write access to his corresponding parameters
  parameter_nodes = [
    {
      "node_name"                = "mgmt-organizations",
      "node_owner_account_id"    = local.account_factory_core_account_ids["aws-c2-management"]
      "node_owner_iam_role_name" = "ntc-oidc-spacelift-role"
    },
    {
      "node_name"                     = "mgmt-account-factory",
      "node_owner_account_id"         = local.account_factory_core_account_ids["aws-c2-management"]
      "node_owner_iam_role_name"      = "ntc-oidc-spacelift-role"
      "node_owner_is_account_factory" = true
    },
    {
      "node_name"                = "mgmt-identity-center",
      "node_owner_account_id"    = local.account_factory_core_account_ids["aws-c2-management"]
      "node_owner_iam_role_name" = "ntc-oidc-spacelift-role"
    },
    {
      "node_name"             = "connectivity"
      "node_owner_account_id" = local.account_factory_core_account_ids["aws-c2-connectivity"]
    },
    {
      "node_name"             = "security-tooling"
      "node_owner_account_id" = local.account_factory_core_account_ids["aws-c2-security"]
    },
    {
      "node_name"             = "log-archive"
      "node_owner_account_id" = local.account_factory_core_account_ids["aws-c2-log-archive"]
    }
  ]

  providers = {
    aws = aws.euc1
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - READER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=1.1.2"

  bucket_name = local.ntc_parameters_bucket_name

  providers = {
    aws = aws.euc1
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - WRITER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_writer" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer?ref=1.1.2"

  bucket_name        = local.ntc_parameters_bucket_name
  parameter_node     = local.ntc_parameters_writer_node
  node_parameters    = local.ntc_parameters_to_write
  store_account_map  = local.ntc_store_account_map
  account_map        = local.ntc_account_map
  replace_parameters = local.ntc_replace_parameters

  providers = {
    aws = aws.euc1
  }
}