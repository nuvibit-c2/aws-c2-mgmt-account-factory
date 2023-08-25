# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # account baseline can either be defined by customer or consumed via template module
  # https://github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates
  account_baseline_templates = [
    {
      file_name     = "security_core"
      template_name = "security_core"
      security_core_inputs = {
        org_management_account_id = data.aws_caller_identity.current.account_id
        security_admin_account_id = local.account_factory_core_account_ids["aws-c2-security"]
        # enable additional securityhub standards
        # security hub enables by default 'aws-foundational-security-best-practices' & 'cis-aws-foundations-benchmark'
        securityhub_enabled_standards = [
          # "aws-foundational-security-best-practices/v/1.0.0",
          # "cis-aws-foundations-benchmark/v/1.2.0",
          # "cis-aws-foundations-benchmark/v/1.4.0",
          # "nist-800-53/v/5.0.0",
          # "pci-dss/v/3.2.1"
        ]
        # new organizations accounts can be auto-enabled in security tooling
        securityhub_auto_enable_organization_members = "NEW"
        guardduty_auto_enable_organization_members   = "NEW"
        # pre-existing accounts can be individually added as members
        enable_organization_members_by_acccount_ids = [
          local.account_factory_core_account_ids["aws-c2-management"],
          local.account_factory_core_account_ids["aws-c2-connectivity"],
          local.account_factory_core_account_ids["aws-c2-log-archive"],
          local.account_factory_all_account_ids["aws-c2-0001"],
          local.account_factory_all_account_ids["aws-c2-0002"],
        ]
        # omit if you dont want to archive guardduty findings in s3
        guardduty_log_archive_bucket_arn  = try(local.ntc_parameters["log-archive"]["log_bucket_arns"]["guardduty"], "")
        guardduty_log_archive_kms_key_arn = try(local.ntc_parameters["log-archive"]["log_bucket_kms_key_arns"]["guardduty"], "")
        # s3 bucket and kms key arn is required if config is in list of service_principals
        config_log_archive_bucket_arn  = try(local.ntc_parameters["log-archive"]["log_bucket_arns"]["aws_config"], "")
        config_log_archive_kms_key_arn = try(local.ntc_parameters["log-archive"]["log_bucket_kms_key_arns"]["aws_config"], "")
        # admin delegations and regional settings will be provisioned for each service
        service_principals = [
          "config.amazonaws.com",
          "guardduty.amazonaws.com",
          "securityhub.amazonaws.com"
        ]
      }
    },
    {
      file_name     = "security_member"
      template_name = "security_member"
      security_core_inputs = {
        # s3 bucket and kms key arn is required if config is in list of service_principals
        config_log_archive_bucket_arn  = try(local.ntc_parameters["log-archive"]["log_bucket_arns"]["aws_config"], "")
        config_log_archive_kms_key_arn = try(local.ntc_parameters["log-archive"]["log_bucket_kms_key_arns"]["aws_config"], "")
        # regional settings will be provisioned for each service
        service_principals = [
          "config.amazonaws.com",
          # "guardduty.amazonaws.com",
          "securityhub.amazonaws.com"
        ]
      }
    },
    {
      file_name     = "iam_role_admin"
      template_name = "iam_role"
      iam_role_inputs = {
        role_name = "baseline_execution_role_admin"
        # policy can be submitted directly as JSON or via data source aws_iam_policy_document
        policy_json = jsonencode(
          {
            "Version" : "2012-10-17",
            "Statement" : [
              {
                "Effect" : "Allow",
                "Action" : "*",
                "Resource" : "*"
              }
            ]
          }
        )
        role_principal_type = "AWS"
        # grant account (org management) permission to assume role in member account
        role_principal_identifiers = [data.aws_caller_identity.current.account_id]
      }
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC ACCOUNT BASELINE TEMPLATES
# ---------------------------------------------------------------------------------------------------------------------
module "account_baseline_templates" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates?ref=1.0.1"

  account_baseline_templates = local.account_baseline_templates
}
