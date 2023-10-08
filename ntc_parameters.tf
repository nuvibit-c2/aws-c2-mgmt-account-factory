locals {
  ntc_parameters_bucket_name = "aws-c2-ntc-parameters"
  ntc_parameters_writer_node = "account-factory"

  # parameters that are managed by org management account
  ntc_parameters_to_write = {
    core_accounts = local.account_factory_core_account_ids
  }

  # node owner that is also the account factory can optionally store an account map
  ntc_store_account_map = true
  ntc_account_map = {
    for account in local.account_factory_list_enriched : account.account_id => account
  }

  # the ntc parameter bucket should ideally be created in same pipeline as account factory
  # all organization accounts are granted read permission for all parameters
  # only the parameter node owner account is granted write access to his corresponding parameters
  ntc_parameter_nodes = [
    {
      "node_name"                = "management",
      "node_owner_account_id"    = local.account_factory_core_account_ids["aws-c2-management"]
      "node_owner_iam_user_name" = "aws-c2-management"
    },
    {
      "node_name"                     = "account-factory",
      "node_owner_account_id"         = local.account_factory_core_account_ids["aws-c2-management"]
      "node_owner_iam_user_name"      = "aws-c2-account-factory"
      "node_owner_is_account_factory" = true
    },
    {
      "node_name"                = "identity-center",
      "node_owner_account_id"    = local.account_factory_core_account_ids["aws-c2-management"]
      "node_owner_iam_user_name" = "aws-c2-identity-center"
    },
    {
      "node_name"             = "connectivity"
      "node_owner_account_id" = local.account_factory_core_account_ids["aws-c2-connectivity"]
    },
    {
      "node_name"             = "security"
      "node_owner_account_id" = local.account_factory_core_account_ids["aws-c2-security"]
    },
    {
      "node_name"             = "log-archive"
      "node_owner_account_id" = local.account_factory_core_account_ids["aws-c2-log-archive"]
    }
  ]

  # by default existing node parameters will be merged with new parameters to avoid deleting parameters
  ntc_parameters_replace = true

  # parameters are shared with parameter node owners by default and with the entire organization if org_id is specified
  share_parameters_with_entire_org = false

  # map of parameters merged from all parameter nodes
  ntc_parameters = module.ntc_parameters_reader.all_parameters
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - BUCKET (DEPLOY FIRST)
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_bucket" {
  # source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters?ref=1.0.0"
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters?ref=feat-account-map"

  force_destroy   = false
  bucket_name     = local.ntc_parameters_bucket_name
  org_id          = local.share_parameters_with_entire_org ? data.aws_organizations_organization.current.id : ""
  parameter_nodes = local.ntc_parameter_nodes

  providers = {
    aws = aws.euc1
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - READER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader" {
  # source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=1.0.0"
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=feat-account-map"

  bucket_name = local.ntc_parameters_bucket_name

  providers = {
    aws = aws.euc1
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - WRITER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_writer" {
  # source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer?ref=1.0.0"
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer?ref=feat-account-map"

  bucket_name        = local.ntc_parameters_bucket_name
  parameter_node     = local.ntc_parameters_writer_node
  node_parameters    = local.ntc_parameters_to_write
  replace_parameters = local.ntc_parameters_replace
  # (optional) account factory can store an account map
  store_account_map = local.ntc_store_account_map
  account_map       = local.ntc_account_map

  providers = {
    aws = aws.euc1
  }
}