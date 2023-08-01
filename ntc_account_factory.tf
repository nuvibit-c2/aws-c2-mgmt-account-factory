# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # this bucket stores required files for account factory
  account_factory_bucket_name = "aws-c2-ntc-account-factory"

  # this bucket stores required cloudtrail logs for account factory
  account_factory_cloudtrail_bucket_name = "aws-c2-ntc-af-cloudtrail"

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
      # add delay to pipeline to avoid errors on first run
      # in this case pipeline will wait for up to 10 minutes for dependencies to resolve
      pipeline_delay_options = {
        wait_for_seconds    = 120
        wait_retry_count    = 5
        wait_for_regions    = true
        wait_for_aws_config = true
        wait_for_guardduty  = true
      }
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
      aws_provider_version  = "4.66.0"
      decommission_all      = false
      baseline_terraform_files = [
        local.account_baseline_terraform_files["security_core"]
      ]
      # apply security-core baseline in all enabled regions
      regions     = data.aws_regions.enabled.names
      main_region = "eu-central-1"
      # security-core baseline should first be rolled out for org-management account
      target_account_names = [
        # "aws-c2-management",
        # "aws-c2-security",
        # "aws-c2-log-archive",
        # "aws-c2-connectivity"
      ]
      target_account_tags = [
        {
          key   = "AccountType"
          value = "core"
        }
      ]
    }
  ]

  # increase quotas for aws services used in account factory
  account_factory_increase_aws_service_quotas = {
    codebuild_concurrent_runs_arm_small = 20
  }

  # can be stored as HCL or alternatively as JSON for easy integration e.g. self service portal integration via git
  account_factory_list = jsondecode(file("${path.module}/ntc_account_factory_manifest.json"))

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
# ¦ NTC ACCOUNT FACTORY
# ---------------------------------------------------------------------------------------------------------------------
module "account_factory" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory?ref=beta"

  account_factory_list                   = local.account_factory_list
  account_factory_bucket_name            = local.account_factory_bucket_name
  account_factory_cloudtrail_bucket_name = local.account_factory_cloudtrail_bucket_name
  account_factory_notification_settings  = local.account_factory_notification_settings
  account_lifecycle_customization_steps  = local.account_factory_lifecycle_customization_steps
  account_baseline_scopes                = local.account_factory_account_baseline_scopes
  increase_aws_service_quotas            = local.account_factory_increase_aws_service_quotas

  providers = {
    aws           = aws.euc1
    aws.us_east_1 = aws.use1 # required for account lifecycle cloudtrail
  }
}