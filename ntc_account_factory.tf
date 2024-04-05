# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # get values from module outputs
  # get account ids for all accounts and for core accounts
  account_factory_all_account_ids = module.account_factory.account_factory_account_ids
  account_factory_core_account_ids = {
    for account in local.account_factory_list_enriched : account.account_name => account.account_id
    if account.account_tags.AccountType == "core"
  }

  # original account map enriched with additional values e.g. account id
  account_factory_list = jsondecode(file("${path.module}/account_list.json"))
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
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory?ref=1.5.0"

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

  # -------------------------------------------------------------------------------------------------------------------
  # ¦ ACCOUNT BASELINE
  # -------------------------------------------------------------------------------------------------------------------
  # list of baseline definitions for accounts in a specific scope
  account_baseline_scopes = [
    {
      scope_name           = "global"
      terraform_version    = "1.6.5"
      aws_provider_version = "5.26.0"
      # (optional) define provider default tags which will be applied to all baseline resources
      provider_default_tags = {
        ManagedBy       = "ntc-account-factory",
        BaselineScope   = "global",
        BaselineVersion = "1.0"
      }
      # (optional) reduce parallelism to avoid api rate limits when deploying to multiple regions
      terraform_parallelism = 10
      # (optional) schedule baseline pipelines to rerun every x hours
      schedule_rerun_every_x_hours = 0
      # (optional) IAM role which exists in member accounts and can be assumed by baseline pipeline
      baseline_execution_role_name = "OrganizationAccountAccessRole"
      # add terraform code to baseline from static files or dynamic templates
      baseline_terraform_files = [
        # {
        #   file_name                     = "baseline_openid_connect"
        #   content                       = templatefile("${path.module}/files/baseline_openid_connect.tftpl", { role_name = "example-role" })
        #   terraform_version_minimum     = "1.3.9"
        #   aws_provider_version_minimum  = "4.59.0"
        # },
        module.account_baseline_templates.account_baseline_terraform_files["iam_role_admin"],
        module.account_baseline_templates.account_baseline_terraform_files["oidc_spacelift"]
      ]
      # add delay to pipeline to avoid errors on first run
      # in this case pipeline will wait for up to 10 minutes for dependencies to resolve
      pipeline_delay_options = {
        wait_for_seconds        = 120
        wait_retry_count        = 5
        wait_for_execution_role = true
        wait_for_regions        = true
        wait_for_securityhub    = true
        wait_for_guardduty      = true
      }
      # baseline terraform code will be provisioned in each specified region
      baseline_regions = ["eu-central-1"]
      # baseline terraform code which can be provisioned in a single region (e.g. IAM)
      baseline_main_region = "eu-central-1"
      # accounts which should be included in baseline scope
      include_accounts_all         = true
      include_accounts_by_ou_paths = []
      include_accounts_by_names    = []
      include_accounts_by_tags     = []
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
    {
      scope_name           = "security-core"
      terraform_version    = "1.6.5"
      aws_provider_version = "5.26.0"
      # (optional) define provider default tags which will be applied to all baseline resources
      provider_default_tags = {
        ManagedBy       = "ntc-account-factory",
        BaselineScope   = "security-core",
        BaselineVersion = "1.0"
      }
      # (optional) reduce parallelism to avoid api rate limits when deploying to multiple regions
      terraform_parallelism = 10
      # (optional) schedule baseline pipelines to rerun every x hours
      schedule_rerun_every_x_hours = 24
      # (optional) IAM role which exists in member accounts and can be assumed by baseline pipeline
      baseline_execution_role_name = "OrganizationAccountAccessRole"
      # add terraform code to baseline from static files or dynamic templates
      baseline_terraform_files = [
        module.account_baseline_templates.account_baseline_terraform_files["security_core"]
      ]
      # add delay to pipeline to avoid errors on first run
      # in this case pipeline will wait for up to 10 minutes for dependencies to resolve
      pipeline_delay_options = {
        wait_for_seconds        = 120
        wait_retry_count        = 5
        wait_for_execution_role = true
        wait_for_regions        = true
        wait_for_securityhub    = false
        wait_for_guardduty      = false
      }
      # apply security-core baseline in all enabled regions
      baseline_regions = data.aws_regions.enabled.names
      # baseline terraform code which can be provisioned in a single region (e.g. IAM)
      baseline_main_region = "eu-central-1"
      # accounts which should be included in baseline scope
      include_accounts_all         = false
      include_accounts_by_ou_paths = []
      /** security-core baseline has a specific rollout order
      WARNING: inspector2 has a bug with regions which don't support LAMBDA_CODE
      https://github.com/hashicorp/terraform-provider-aws/issues/34039#issuecomment-1974906732

      1. in 'security-core' baseline template set 'security_admin_account_initial_run' to 'true'
      2. roll out 'security-core' baseline first exclusively to security admin account
      3. add org-management account to baseline scope to delegate admin permission to security account
      4. in baseline template set 'security_admin_account_initial_run' to 'false'
      5. wait for security admin account and org-management account baseline to rerun successfully
      6. add remaining core accounts to baseline scope
      **/
      include_accounts_by_names = [
        # "aws-c2-security",
        # "aws-c2-management"
      ]
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
    {
      scope_name           = "workloads-prod"
      terraform_version    = "1.6.5"
      aws_provider_version = "5.26.0"
      # (optional) define provider default tags which will be applied to all baseline resources
      provider_default_tags = {
        ManagedBy       = "ntc-account-factory",
        BaselineScope   = "workloads-prod",
        BaselineVersion = "1.0"
      }
      # (optional) reduce parallelism to avoid api rate limits when deploying to multiple regions
      terraform_parallelism = 10
      # (optional) schedule baseline pipelines to rerun every x hours
      schedule_rerun_every_x_hours = 0
      # (optional) IAM role which exists in member accounts and can be assumed by baseline pipeline
      baseline_execution_role_name = "OrganizationAccountAccessRole"
      # add terraform code to baseline from static files or dynamic templates
      baseline_terraform_files = [
        module.account_baseline_templates.account_baseline_terraform_files["security_member"]
      ]
      # add delay to pipeline to avoid errors on first run
      # in this case pipeline will wait for up to 10 minutes for dependencies to resolve
      pipeline_delay_options = {
        wait_for_seconds        = 120
        wait_retry_count        = 5
        wait_for_execution_role = true
        wait_for_regions        = true
        wait_for_securityhub    = true
        wait_for_guardduty      = true
      }
      # baseline terraform code will be provisioned in each specified region
      baseline_regions = ["us-east-1", "eu-central-1"]
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
    }
  ]

  providers = {
    aws           = aws.euc1
    aws.us_east_1 = aws.use1 # required for account lifecycle cloudtrail
  }
}