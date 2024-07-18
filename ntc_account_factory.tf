# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # get values from module outputs
  # get account ids for all accounts and for core accounts
  account_factory_all_account_ids = module.ntc_account_factory.account_factory_account_ids
  account_factory_core_account_ids = {
    for account in local.account_factory_list_enriched : account.account_name => account.account_id
    if account.account_tags.AccountType == "core"
  }

  # original account map enriched with additional values e.g. account id
  account_factory_list = concat(
    jsondecode(file("${path.module}/account_list_core.json")),
    jsondecode(file("${path.module}/account_list_workloads.json")),
  )
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
module "ntc_account_factory" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory?ref=1.6.0"

  # this bucket stores required files for account factory
  account_factory_baseline_bucket_name = "aws-c2-ntc-af-baseline"

  # this bucket stores required cloudtrail logs for account factory
  account_factory_cloudtrail_bucket_name = "aws-c2-ntc-af-cloudtrail"

  # increase quotas for aws services used in account factory
  increase_aws_service_quotas = {
    codebuild_concurrent_runs_arm_small = 20
  }

  # account names and emails cannot be changed without manual intervention - set naming conventions to avoid mistakes
  account_factory_naming_conventions = {
    account_name_regex  = "^aws-c2-[a-z0-9-]+$"
    account_email_regex = "@nuvibit.com$"
  }

  # can be stored as HCL or alternatively as JSON for easy integration e.g. self service portal integration via git
  account_factory_list = local.account_factory_list

  # notify on account lifecycle step functions or account baseline pipeline errors
  account_factory_notification_settings = {
    # identify for which AWS Organization notifications are sent
    org_identifier = "c2"
    # multiple subscriptions with different protocols is supported
    subscriptions = [
      {
        protocol  = "email"
        endpoints = ["stefano.franco@nuvibit.com"]
      }
    ]
  }

  # (optional) credentials if you want to reference Terraform modules in your account baseline
  # https://developer.hashicorp.com/terraform/language/modules/sources
  # WARNING: do not store credentials in clear text in git - reference from a vault or from environment variable
  account_baseline_git_ssh_key              = "credential_1"
  account_baseline_github_access_token      = "credential_2"
  account_baseline_terraform_registry_token = "credential_3"
  account_baseline_terraform_registry_host  = "spacelift.io"

  # -------------------------------------------------------------------------------------------------------------------
  # ¦ ACCOUNT LIFECYCLE CUSTOMIZATION
  # -------------------------------------------------------------------------------------------------------------------
  # provide lambda packages for additional account lifecycle customization e.g. delete default vpc
  # trigger for the lambda step functions are cloudtrail events with event source 'organizations.amazonaws.com'
  account_lifecycle_customization_steps = [
    {
      # organizations event (e.g. when a new AWS account is created) that should trigger a lambda step_sequence
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
        module.account_lifecycle_customization_templates.account_lifecycle_customization_steps["enable_opt_in_regions"],
        module.account_lifecycle_customization_templates.account_lifecycle_customization_steps["delete_default_vpc"],
        module.account_lifecycle_customization_templates.account_lifecycle_customization_steps["invite_security_members"],
        module.account_lifecycle_customization_templates.account_lifecycle_customization_steps["increase_service_quota"],
        module.account_lifecycle_customization_templates.account_lifecycle_customization_steps["tag_shared_resources"]
      ]
    },
    {
      organizations_event_trigger = "CloseAccountResult"
      step_sequence = [
        module.account_lifecycle_customization_templates.account_lifecycle_customization_steps["move_to_suspended_ou"]
      ]
    }
  ]

  # list of baseline definitions for accounts in a specific scope
  account_baseline_scopes = [
    # -----------------------------------------------------------------------------------------------------------------
    # ¦ ACCOUNT BASELINE - CORE ACCOUNTS
    # -----------------------------------------------------------------------------------------------------------------
    {
      scope_name = "core-accounts"
      # you can use the opentofu binary instead of terraform for account baseline pipelines
      terraform_binary = "opentofu"
      # (optional) reduce parallelism to avoid api rate limits when deploying to multiple regions
      terraform_parallelism = 10
      # https://github.com/hashicorp/terraform/releases
      # https://github.com/opentofu/opentofu/releases
      terraform_version    = "1.7.3"
      aws_provider_version = "5.58.0"
      # (optional) define provider default tags which will be applied to all baseline resources
      provider_default_tags = {
        ManagedBy       = "ntc-account-factory",
        BaselineScope   = "core-accounts",
        BaselineVersion = "1.0"
      }
      # (optional) schedule baseline pipelines to rerun every x hours
      schedule_rerun_every_x_hours = 0
      # (optional) IAM role which exists in member accounts and can be assumed by baseline pipeline
      baseline_execution_role_name = "OrganizationAccountAccessRole"
      # add terraform code to baseline from static files or dynamic templates
      baseline_terraform_files = [
        module.account_baseline_templates.account_baseline_terraform_files["iam_grafana_reader"],
        module.account_baseline_templates.account_baseline_terraform_files["oidc_spacelift"],
      ]
      # add delay to pipeline to avoid errors on first run
      # in this case pipeline will wait for up to 10 minutes for dependencies to resolve
      pipeline_delay_options = {
        wait_for_seconds        = 120
        wait_retry_count        = 5
        wait_for_execution_role = true
        wait_for_regions        = false
        wait_for_securityhub    = false
        wait_for_guardduty      = false
      }
      # baseline terraform code will be provisioned in each specified region
      baseline_regions = ["us-east-1", "eu-central-1", "eu-central-2"] # data.aws_regions.enabled.names
      # baseline terraform code which can be provisioned in a single region (e.g. IAM)
      baseline_main_region = "eu-central-1"
      # accounts which should be included in baseline scope
      include_accounts_all         = false
      include_accounts_by_ou_paths = []
      include_accounts_by_names    = []
      include_accounts_by_tags = [
        {
          key   = "AccountType"
          value = "core"
        }
      ]
      # accounts which should be excluded in baseline scope
      exclude_accounts_by_ou_paths = []
      exclude_accounts_by_names    = []
      exclude_accounts_by_tags     = []
      # decomissioning of baseline terraform resources must be done before deleting the scope!
      # decommission baseline terraform code for specific accounts in scope
      decommission_accounts_all         = false
      decommission_accounts_by_ou_paths = []
      decommission_accounts_by_names    = []
      decommission_accounts_by_tags = [
        {
          key   = "AccountDecommission"
          value = true
        }
      ]
    },
    # -----------------------------------------------------------------------------------------------------------------
    # ¦ ACCOUNT BASELINE - WORKLOAD ACCOUNTS - PROD
    # -----------------------------------------------------------------------------------------------------------------
    {
      scope_name = "workloads-prod"
      # you can use the opentofu binary instead of terraform for account baseline pipelines
      terraform_binary = "terraform"
      # (optional) reduce parallelism to avoid api rate limits when deploying to multiple regions
      terraform_parallelism = 10
      # https://github.com/hashicorp/terraform/releases
      # https://github.com/opentofu/opentofu/releases
      terraform_version    = "1.6.5"
      aws_provider_version = "5.26.0"
      # (optional) define provider default tags which will be applied to all baseline resources
      provider_default_tags = {
        ManagedBy       = "ntc-account-factory",
        BaselineScope   = "workloads-prod",
        BaselineVersion = "1.0"
      }
      # (optional) schedule baseline pipelines to rerun every x hours
      schedule_rerun_every_x_hours = 0
      # (optional) IAM role which exists in member accounts and can be assumed by baseline pipeline
      baseline_execution_role_name = "OrganizationAccountAccessRole"
      # add terraform code to baseline from static files or dynamic templates
      baseline_terraform_files = [
        module.account_baseline_templates.account_baseline_terraform_files["iam_grafana_reader"],
        module.account_baseline_templates.account_baseline_terraform_files["oidc_spacelift"],
      ]
      # add delay to pipeline to avoid errors on first run
      # in this case pipeline will wait for up to 10 minutes for dependencies to resolve
      pipeline_delay_options = {
        wait_for_seconds        = 120
        wait_retry_count        = 5
        wait_for_execution_role = true
        wait_for_regions        = false
        wait_for_securityhub    = false
        wait_for_guardduty      = false
      }
      # baseline terraform code will be provisioned in each specified region
      baseline_regions = ["us-east-1", "eu-central-1", "eu-central-2"]
      # baseline terraform code which can be provisioned in a single region (e.g. IAM)
      baseline_main_region = "eu-central-1"
      # accounts which should be included in baseline scope
      include_accounts_all = false
      include_accounts_by_ou_paths = [
        "/root/workloads/prod",
      ]
      include_accounts_by_names = [
        # "aws-c2-0002",
      ]
      include_accounts_by_tags = [
        # {
        #   key   = "AccountType"
        #   value = "workload"
        # }
      ]
      # accounts which should be excluded in baseline scope
      exclude_accounts_by_ou_paths = []
      exclude_accounts_by_names = [
        # "aws-c2-0002",
      ]
      exclude_accounts_by_tags = []
      # decomissioning of baseline terraform resources must be done before deleting the scope!
      # decommission baseline terraform code for specific accounts in scope
      decommission_accounts_all         = false
      decommission_accounts_by_ou_paths = []
      decommission_accounts_by_names = [
        # "aws-c2-0002",
      ]
      decommission_accounts_by_tags = [
        {
          key   = "AccountDecommission"
          value = true
        }
      ]
    },
    # -----------------------------------------------------------------------------------------------------------------
    # ¦ ACCOUNT BASELINE - TEST CREDENTIALS
    # -----------------------------------------------------------------------------------------------------------------
    {
      scope_name                   = "test-credentials"
      terraform_binary             = "opentofu"
      terraform_version            = "1.7.3"
      aws_provider_version         = "5.58.0"
      baseline_execution_role_name = "OrganizationAccountAccessRole"
      baseline_terraform_files = [
        {
          file_name = "test_credentials"
          content   = templatefile("${path.module}/files/account_baseline_example.tf", {})
          # terraform_version_minimum    = "1.3.9"
          # aws_provider_version_minimum = "4.59.0"
        }
      ]
      pipeline_delay_options = {
        wait_for_seconds        = 120
        wait_retry_count        = 5
        wait_for_execution_role = true
        wait_for_regions        = false
        wait_for_securityhub    = false
        wait_for_guardduty      = false
      }
      baseline_regions             = ["eu-central-1"]
      baseline_main_region         = "eu-central-1"
      include_accounts_all         = false
      include_accounts_by_ou_paths = []
      include_accounts_by_names = [
        "aws-c2-0001",
      ]
      include_accounts_by_tags          = []
      exclude_accounts_by_ou_paths      = []
      exclude_accounts_by_names         = []
      exclude_accounts_by_tags          = []
      decommission_accounts_all         = false
      decommission_accounts_by_ou_paths = []
      decommission_accounts_by_names = [
        # "aws-c2-0001",
      ]
      decommission_accounts_by_tags = []
    }
  ]

  providers = {
    aws           = aws.euc1
    aws.us_east_1 = aws.use1 # required for account lifecycle cloudtrail
  }
}