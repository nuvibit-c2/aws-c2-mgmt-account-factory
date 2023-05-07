# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # this bucket stores required files for account factory
  account_factory_bucket_name = "aws-c2-ntc-account-factory"
  # this bucket stores required cloudtrail logs for account factory
  account_factory_cloudtrail_bucket_name = "aws-c2-ntc-af-cloudtrail"

  # provide lambda packages for additional account lifecycle customization e.g. delete default vpc
  # trigger for the lambda step functions are cloudtrail events with event source 'organizations.amazonaws.com'
  account_factory_lifecycle_customization_steps = [
    {
      step_name                  = "on_account_creation_delete_default_vpc"
      organizations_event_name   = "CreateAccountResult"
      lambda_package_source_path = "${path.module}/customization-examples/delete-default-vpc"
      lambda_file_name           = "main.py"
      environment_variables      = {}
    },
    {
      step_name                  = "on_account_deletion_move_account_to_suspended_ou"
      organizations_event_name   = "CloseAccountResult"
      lambda_package_source_path = "${path.module}/customization-examples/move-to-suspended-ou"
      lambda_file_name           = "main.py"
      environment_variables = {
        "SUSPENDED_OU_ID" : local.ntc_parameters["management"]["organization"]["ou_ids"]["/root/suspended"]
      }
    }
  ]

  # notify on step functions or pipeline errors via email
  account_factory_notification_email_subscribers = ["stefano.franco@nuvibit.com"]

  # list of baseline definitions for accounts in a specific scope
  account_factory_baseline_scopes = [
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
      baseline_terraform_contents = [
        file("${path.module}/baseline-examples/baseline_iam+vpc.tf")
        # templatefile("${path.module}/baseline-examples/baseline_iam+vpc.tftpl", { vpc_cidr = "192.168.0.0/24" })
      ]
      # baseline terraform code will be provisioned in each specified region
      regions = ["us-east-1", "eu-central-1"]
      # baseline terraform code which can be provisioned in a single region (e.g. IAM)
      main_region = "eu-central-1"
      # add accounts to this baseline scope by ou_path
      target_ou_paths = [
        "/root/workloads/prod"
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
# ¦ NTC ACCOUNT FACTORY
# ---------------------------------------------------------------------------------------------------------------------
module "account_factory" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory?ref=beta"

  account_factory_list                   = local.account_factory_list
  account_factory_bucket_name            = local.account_factory_bucket_name
  account_factory_cloudtrail_bucket_name = local.account_factory_cloudtrail_bucket_name
  account_lifecycle_customization_steps  = local.account_factory_lifecycle_customization_steps
  # baseline_scopes                        = local.account_factory_baseline_scopes
  notification_email_subscribers         = local.account_factory_notification_email_subscribers

  providers = {
    aws           = aws.euc1
    aws.us_east_1 = aws.use1
  }
}