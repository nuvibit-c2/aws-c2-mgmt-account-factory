locals {
  ntc_parameters_bucket_name = "aws-c2-ntc-parameters"
  ntc_parameters_writer_node = "mgmt-account-factory"

  # parameters to store in the ntc-parameters bucket
  ntc_parameters_to_write = {
    "core_accounts"      = local.account_factory_core_account_ids
    "baseline_role_arns" = module.ntc_account_factory.account_factory_baseline_iam_role_arns
  }

  # node owner that is also the account factory can optionally store an account map
  ntc_account_map = {
    for account in local.account_factory_list_enriched : account.account_id => account
  }

  # map of parameters merged from all parameter nodes
  ntc_parameters = module.ntc_parameters_reader.all_parameters
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - READER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_reader" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=1.1.4"

  bucket_name = local.ntc_parameters_bucket_name

  providers = {
    aws = aws.euc1
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - WRITER
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_writer" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer?ref=1.1.4"

  bucket_name        = local.ntc_parameters_bucket_name
  parameter_node     = local.ntc_parameters_writer_node
  node_parameters    = local.ntc_parameters_to_write
  replace_parameters = true
  store_account_map  = true
  account_map        = local.ntc_account_map

  providers = {
    aws = aws.euc1
  }
}