# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # this bucket stores required files for account factory
  account_factory_bucket_name = "aws-c2-ntc-account-factory"

  # this bucket stores required cloudtrail logs for account factory
  account_factory_cloudtrail_bucket_name = "aws-c2-ntc-af-cloudtrail"

  # customization steps can either be defined by customer or consumed via template module
  # https://github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-lifecycle-templates
  account_factory_lifecycle_customization_templates = [
    {
      template_name               = "enable_opt_in_regions"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
      opt_in_regions              = ["eu-central-2"]
    },
    {
      template_name               = "increase_service_quota"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
    },
    {
      template_name               = "delete_default_vpc"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
    },
    {
      template_name               = "move_to_suspended_ou"
      organizations_event_trigger = "CloseAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
      suspended_ou_id             = local.ntc_parameters["management"]["organization"]["ou_ids"]["/root/suspended"]
    }
  ]
  # template module outputs customization steps grouped by template name
  account_lifecycle_customization_steps = module.accounf_lifecycle_templates["account_lifecycle_customization_steps"]

  # provide lambda packages for additional account lifecycle customization e.g. delete default vpc
  # trigger for the lambda step functions are cloudtrail events with event source 'organizations.amazonaws.com'
  account_factory_lifecycle_customization_steps = [
    {
      # organizations event (e.g. when a new AWS account is created) which should trigger a lambda step_sequence
      organizations_event_trigger = "CreateAccountResult"
      # step sequence defines the order in which lambda steps are executed
      step_sequence = [
        # {
        #   step_name                  = "on_account_creation_enable_opt_in_regions"
        #   lambda_package_source_path = "INSERT_LAMBDA_SOURCE_PATH"
        #   lambda_handler             = "main.lambda_handler"
        #   environment_variables = {
        #     "ORGANIZATIONS_MEMBER_ROLE" : "OrganizationAccountAccessRole"
        #     "OPT_IN_REGIONS" : jsonencode(["eu-central-2"])
        #     "DEFAULT_REGION" : "eu-central-1"
        #   }
        # }
        local.account_lifecycle_customization_steps["enable_opt_in_regions"],
        local.account_lifecycle_customization_steps["increase_service_quota"],
        local.account_lifecycle_customization_steps["delete_default_vpc"]
      ]
    },
    {
      organizations_event_trigger = "CloseAccountResult"
      step_sequence = [
        local.account_lifecycle_customization_steps["move_to_suspended_ou"]
      ]
    }
  ]

  # notify on account lifecycle step functions or account baseline pipeline errors
  account_factory_notification_settings = {
    # multiple subscriptions with different protocols is supported
    subscriptions = [
      {
        protocol  = "email"
        endpoints = ["stefano.franco@nuvibit.com"]
      }
    ]
  }

  # account baseline can either be defined by customer or consumed via template module
  # https://github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates
  account_factory_baseline_templates = [
    {
      file_name     = "security_core"
      template_name = "security_core"
      security_core_inputs = {
        org_management_account_id = data.aws_caller_identity.current.account_id
        security_admin_account_id = local.account_factory_core_account_ids["aws-c2-security"]
        # new organizations accounts can be auto-enabled in security tooling
        securityhub_auto_enable_organization_members = "NEW"
        guardduty_auto_enable_organization_members   = "NEW"
        # pre-existing accounts can be individually added as members
        enable_organization_members_by_acccount_ids = [
          "228120440352"
        ]
        # omit if you dont want to archive guardduty findings in s3
        guardduty_log_archive_bucket_arn  = try(local.ntc_parameters["log-archive"]["log_bucket_arns"]["guardduty"], "")
        guardduty_log_archive_kms_key_arn = try(local.ntc_parameters["log-archive"]["log_bucket_kms_key_arns"]["guardduty"], "")
        # admin delegations and regional settings will be provisioned for each service
        service_principals = [
          "config.amazonaws.com",
          "guardduty.amazonaws.com",
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
  # template module outputs terraform baseline files grouped by template name
  account_baseline_terraform_files = module.accounf_baseline_templates["account_baseline_terraform_files"]

  # list of baseline definitions for accounts in a specific scope
  account_factory_account_baseline_scopes = [
    {
      scope_name           = "workloads-prod"
      terraform_version    = "1.3.9"
      aws_provider_version = "4.59.0"
      # decomissioning of baseline terraform resources must be done before deleting the scope!
      # decommission baseline terraform code for all accounts in scope
      decommission_all = false
      # (optional) decommission baseline terraform code for specific accounts in scope
      decommission_account_names = []
      # (optional) schedule baseline pipelines to rerun every x hours
      schedule_rerun_every_x_hours = 0
      # (optional) IAM role which exists in member accounts and can be assumed by baseline pipeline
      baseline_execution_role_name = "OrganizationAccountAccessRole"
      # add terraform code to baseline from static files or dynamic templates
      baseline_terraform_files = [
        # {
        #   file_name = "baseline_iam_roles"
        #   content   = templatefile("${path.module}/files/baseline_iam_roles.tftpl", { role_name = "example-role" })
        # },
        local.account_baseline_terraform_files["iam_role_admin"]
      ]
      # baseline terraform code will be provisioned in each specified region
      regions = ["us-east-1", "eu-central-1"]
      # baseline terraform code which can be provisioned in a single region (e.g. IAM)
      main_region = "eu-central-1"
      # at least one target must be defined but multiple targets can be combined
      # (optional) add accounts to this baseline scope by exact ou_path
      target_ou_paths = [
        "/root/workloads/prod",
        "/root/workloads/dev"
      ]
      # (optional) add accounts to this baseline scope by name
      target_account_names = [
        # "aws-c2-0001",
        # "aws-c2-0002"
      ]
      # (optional) add accounts to this baseline scope by tags
      target_account_tags = [
        # {
        #   key   = "AccountType"
        #   value = "workload"
        # }
      ]
    },
    {
      scope_name = "security-core"
      # reduce parallelism to avoid api rate limits when deploying to multiple regions
      terraform_parallelism = 2
      terraform_version     = "1.3.9"
      aws_provider_version  = "4.59.0"
      decommission_all      = false
      baseline_terraform_files = [
        local.account_baseline_terraform_files["security_core"]
      ]
      # apply security-core baseline in all enabled regions
      regions     = data.aws_regions.enabled.names
      main_region = "eu-central-1"
      target_account_names = [
        "aws-c2-management",
        "aws-c2-security"
      ]
    }
  ]

  # can be stored as HCL or alternatively as JSON for easy integration e.g. self service portal integration via git
  account_factory_list = jsondecode(file("${path.module}/ntc_account_factory_list.json"))

  # get values from module outputs
  # get account ids for all accounts and for core accounts
  account_factory_all_account_ids = module.account_factory.account_factory_account_ids
  account_factory_core_account_ids = {
    for account in local.account_factory_list_enriched : account.account_name => account.account_id
    if account.account_tags.AccountType == "core"
  }

  # original account map enriched with additional values e.g. account id
  account_factory_list_enriched = [
    for account in local.account_factory_list : merge(account,
      {
        account_id = local.account_factory_all_account_ids[account.account_name]
      }
    )
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC ACCOUNT LIFECYCLE CUSTOMIZATION TEMPLATES
# ---------------------------------------------------------------------------------------------------------------------
module "accounf_lifecycle_templates" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-lifecycle-templates?ref=beta"

  account_lifecycle_customization_templates = local.account_factory_lifecycle_customization_templates
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC ACCOUNT BASELINE TEMPLATES
# ---------------------------------------------------------------------------------------------------------------------
module "accounf_baseline_templates" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates?ref=beta"

  account_baseline_templates = local.account_factory_baseline_templates
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC ACCOUNT FACTORY
# ---------------------------------------------------------------------------------------------------------------------
module "account_factory" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory?ref=beta"

  account_factory_list                   = local.account_factory_list
  account_factory_bucket_name            = local.account_factory_bucket_name
  account_factory_cloudtrail_bucket_name = local.account_factory_cloudtrail_bucket_name
  account_lifecycle_customization_steps  = local.account_factory_lifecycle_customization_steps
  account_baseline_scopes                = local.account_factory_account_baseline_scopes
  account_factory_notification_settings  = local.account_factory_notification_settings

  providers = {
    aws           = aws.euc1
    aws.us_east_1 = aws.use1 # required for account lifecycle cloudtrail
  }
}