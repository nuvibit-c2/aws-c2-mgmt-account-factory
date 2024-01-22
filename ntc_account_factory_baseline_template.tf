# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC ACCOUNT BASELINE TEMPLATES
# ---------------------------------------------------------------------------------------------------------------------
module "account_baseline_templates" {
  # source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates?ref=1.1.3"
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates?ref=feat-oidc"

  # account baseline can either be defined by customer or consumed via template module
  # https://github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates
  account_baseline_templates = [
    {
      file_name     = "security_core"
      template_name = "security_core"
      security_core_inputs = {
        org_management_account_id = local.account_factory_core_account_ids["aws-c2-management"]
        security_admin_account_id = local.account_factory_core_account_ids["aws-c2-security"]
        # security-core baseline needs to be rolled out first to security admin account and in a second step to org-management account.
        security_admin_account_initial_run = false
        # security hub enables by default 'aws-foundational-security-best-practices' & 'cis-aws-foundations-benchmark'
        # for additional standards disable default standards and add required standards to 'securityhub_enabled_standards'
        securityhub_auto_enable_default_standards = false
        securityhub_enabled_standards = [
          "aws-foundational-security-best-practices/v/1.0.0",
          "cis-aws-foundations-benchmark/v/1.2.0",
          "cis-aws-foundations-benchmark/v/1.4.0",
          # "nist-800-53/v/5.0.0",
          # "pci-dss/v/3.2.1"
        ]
        # consolidate multiple finding controls into a single finding
        securityhub_enable_consolidated_control_findings = true
        # new organizations accounts can be auto-enabled by AWS with a delay (set to "NEW")
        # (optional) enable security members via account lifecycle template 'invite_security_members' instead
        securityhub_auto_enable_organization_members = "NONE"
        guardduty_auto_enable_organization_members   = "NONE"
        # pre-existing accounts can be individually added as members
        # (optional) enable all existing accounts as security members via account lifecycle template 'invite_security_members' instead
        enable_organization_members_by_acccount_ids = []
        # omit if you dont want to archive guardduty findings in s3
        guardduty_log_archive_bucket_arn  = try(local.ntc_parameters["log-archive"]["log_bucket_arns"]["guardduty"], "")
        guardduty_log_archive_kms_key_arn = try(local.ntc_parameters["log-archive"]["log_bucket_kms_key_arns"]["guardduty"], "")
        # s3 bucket and kms key arn is required if config is in list of service_principals
        config_log_archive_bucket_arn  = try(local.ntc_parameters["log-archive"]["log_bucket_arns"]["aws_config"], "")
        config_log_archive_kms_key_arn = try(local.ntc_parameters["log-archive"]["log_bucket_kms_key_arns"]["aws_config"], "")
        # enable inspector scanning. requires inspector to be in list of service_principals
        inspector_enable_ec2_scans    = true
        inspector_enable_ecr_scans    = true
        inspector_enable_lambda_scans = true
        # admin delegations and regional settings will be provisioned for each service
        service_principals = [
          "config.amazonaws.com",
          "securityhub.amazonaws.com",
          "guardduty.amazonaws.com",
          "inspector2.amazonaws.com"
        ]
      }
    },
    {
      file_name     = "security_member"
      template_name = "security_member"
      security_core_inputs = {
        # security hub enables by default 'aws-foundational-security-best-practices' & 'cis-aws-foundations-benchmark'
        securityhub_enabled_standards = [
          "aws-foundational-security-best-practices/v/1.0.0",
          "cis-aws-foundations-benchmark/v/1.2.0",
          "cis-aws-foundations-benchmark/v/1.4.0",
          # "nist-800-53/v/5.0.0",
          # "pci-dss/v/3.2.1"
        ]
        # s3 bucket and kms key arn is required if config is in list of service_principals
        config_log_archive_bucket_arn  = try(local.ntc_parameters["log-archive"]["log_bucket_arns"]["aws_config"], "")
        config_log_archive_kms_key_arn = try(local.ntc_parameters["log-archive"]["log_bucket_kms_key_arns"]["aws_config"], "")
        # regional settings will be provisioned for each service
        service_principals = [
          "config.amazonaws.com",
          "securityhub.amazonaws.com",
          # "guardduty.amazonaws.com",
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
    },
    {
      file_name     = "oidc_spacelift"
      template_name = "openid_connect"
      openid_connect_inputs = {
        provider = "nuvibit.app.spacelift.io"
        audience = "nuvibit.app.spacelift.io"
        role_name                 = "ntc-oidc-spacelift-role"
        role_path                 = "/"
        role_max_session_in_hours = 1
        permission_boundary_arn   = ""
        permission_policy_arn     = "arn:aws:iam::aws:policy/AdministratorAccess"
        # make sure to define a subject which is limited to your scope (e.g. a generic subject could grant access to all terraform cloud users)
        # you can use dynamic values by referencing the injected baseline variables (e.g. var.current_account_name) - additional '$' escape is required
        # for additional flexibility use 'subject_list_encoded' which allows injecting more complex structures (e.g. grant permission to multiple pipelines in one account)
        /* examples for common openid_connect subjects
          terraform cloud = "organization:ORG_NAME:project:PROJECT_NAME:workspace:WORKSPACE_NAME:run_phase:RUN_PHASE"
          spacelift       = "space:SPACE_ID:stack:STACK_ID:run_type:RUN_TYPE:scope:RUN_PHASE"
          gitlab          = "project_path:GROUP_NAME/PROJECT_NAME:ref_type:branch:ref:main"
          github          = "repo:ORG_NAME/REPO_NAME:environment:prod"
          jenkins         = "job:JOB_NAME/master"
        */
        # subject_list = ["space:aws-c2-01HMSG08P7X6MD11FYV831WN2B:stack:$${var.current_account_name}:*"]
        subject_list_encoded = <<EOT
flatten([
  [
    "space:aws-c2-01HMSG08P7X6MD11FYV831WN2B:stack:$${var.current_account_name}:*"
  ],
  [
    for subject in try(var.current_account_customer_values.additional_oidc_subjects, []) : "space:aws-c2-01HMSG08P7X6MD11FYV831WN2B:stack:$${subject}:*"
  ]
])
EOT
      }
    }
  ]
}
