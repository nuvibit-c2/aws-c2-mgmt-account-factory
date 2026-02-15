# =====================================================================================================================
# NTC ACCOUNT FACTORY - AUTOMATED AWS ACCOUNT PROVISIONING AND GOVERNANCE
# =====================================================================================================================
# Centralized system for creating, configuring, and governing AWS accounts at scale
#
# WHAT IS ACCOUNT FACTORY?
# -------------------------
# NTC Account Factory is a comprehensive account vending machine that automates:
#   - AWS account creation and provisioning
#   - Event-driven lifecycle automation (one-time setup tasks)
#   - Continuous governance via account baselines (ongoing state management)
#   - Compliance monitoring and notifications
#
# CORE CAPABILITIES:
# ------------------
# 1. ACCOUNT PROVISIONING
#    - Declarative account definitions via JSON/HCL
#    - Automated account creation through AWS Organizations
#    - Email validation and naming conventions
#    - OU placement and tagging
#
# 2. ACCOUNT LIFECYCLE (Event-Driven)
#    - One-time automation triggered by account events
#    - CreateAccountResult: Setup new accounts
#    - CloseAccountResult: Cleanup closed accounts
#    - Stateless Lambda-based execution
#    - See: 'ntc_account_factory_account_lifecycle_template.tf'
#
# 3. ACCOUNT BASELINE (Continuous Governance)
#    - Stateful Terraform-based configuration management
#    - Multi-region deployment support
#    - Drift detection and remediation
#    - Scheduled execution for compliance
#    - See: 'ntc_account_factory_baseline_template.tf'
#
# ARCHITECTURE OVERVIEW:
# ----------------------
#   Account List (JSON) → Account Factory Module → AWS Organizations API
#        ↓                       ↓                         ↓
#   Validation              CodePipeline             Account Created
#                            CodeBuild                     ↓
#                                ↓                   EventBridge
#                           S3 Buckets                     ↓
#                            DynamoDB                Step Functions → Lambda (Lifecycle)
#                                                          ↓
#                                                    CodePipeline (Baseline)
#                                                          ↓
#                                                    Member Accounts
#
# DEPLOYMENT MODEL:
# -----------------
# Account Factory runs in the Organization Management Account with:
#   - Organizations API access for account creation
#   - Cross-account role assumption for baseline deployment
#   - CloudTrail for lifecycle event triggers
#   - CodePipeline for baseline orchestration
#   - S3 for state and artifact storage
#
# BEST PRACTICES:
# ---------------
# ✓ Define accounts as code (version controlled JSON/HCL)
# ✓ Use naming conventions to prevent mistakes
# ✓ Separate lifecycle (one-time) from baseline (ongoing) concerns
# ✓ Test lifecycle and baseline templates with dedicated accounts first
# ✓ Schedule baseline execution for drift remediation
# ✓ Configure notifications for failures
# ✓ Use scoped baselines for different account types
# ✓ Document baseline scope purposes and requirements
#
# SECURITY CONSIDERATIONS:
# ------------------------
# • Account Factory has elevated privileges (Organizations API access)
# • Baseline execution uses OrganizationAccountAccessRole (admin in members)
# • All actions are logged to CloudTrail
# • Notifications alert on failures and errors
# • State files contain sensitive information (encrypted at rest)
# • Review account list changes carefully (account creation is irreversible)
#
# REFERENCES:
# -----------
# - Docs: https://docs.nuvibit.com/ntc-building-blocks/management/ntc-account-factory/
# - Lifecycle Templates: https://docs.nuvibit.com/ntc-building-blocks/templates/ntc-account-lifecycle-templates/
# - Baseline Templates: https://docs.nuvibit.com/ntc-building-blocks/templates/ntc-account-baseline-templates/
#
# =====================================================================================================================

# =====================================================================================================================
# LOCALS - DERIVED VALUES AND ACCOUNT LIST PROCESSING
# =====================================================================================================================
# Process account lists from JSON files and enrich with runtime information
# =====================================================================================================================
locals {
  # -------------------------------------------------------------------------------------------------------------------
  # Account IDs from Module Outputs
  # -------------------------------------------------------------------------------------------------------------------
  # Retrieve account IDs after Account Factory creates or imports accounts
  # Used for cross-referencing and parameter sharing
  # -------------------------------------------------------------------------------------------------------------------
  account_factory_all_account_ids = module.ntc_account_factory.account_factory_account_ids

  # Filter core accounts for special handling (e.g., cross-account roles, monitoring)
  account_factory_core_account_ids = {
    for account in local.account_factory_list_enriched : account.account_name => account.account_id
    if account.account_tags.AccountType == "core"
  }

  # -------------------------------------------------------------------------------------------------------------------
  # Account List Processing
  # -------------------------------------------------------------------------------------------------------------------
  # Load account definitions from JSON files and merge them
  # 
  # WHY JSON FILES?
  # - Self-Service Portal Integration: JSON is easily generated/consumed by web UIs and APIs
  # - GitOps Workflows: Pull requests for account requests with automated validation
  # - Programmatic Generation: Scripts can easily create/modify account definitions
  # - Language Agnostic: Any tool/language can read and write JSON
  # - Version Control Friendly: Clear diffs, easy code reviews, audit trail
  # 
  # ORGANIZATION STRATEGIES:
  # - Split by account type (core vs workload) for better organization
  # - Single file for small organizations
  # - Multiple files by business unit, environment, or team
  # - HCL-based lists also supported if preferred (locals blocks)
  # 
  # SELF-SERVICE INTEGRATION EXAMPLE:
  # 1. User submits account request via web portal
  # 2. Portal generates JSON entry and creates Git pull request
  # 3. Automated validation checks naming, email, OU placement
  # 4. Approval workflow (manager, security, cloud team)
  # 5. Merge triggers Terraform pipeline → account creation
  # -------------------------------------------------------------------------------------------------------------------
  account_factory_list = concat(
    jsondecode(file("${path.module}/account_list_core.json")),      # Core infrastructure accounts
    jsondecode(file("${path.module}/account_list_sandbox.json")),   # Sandbox accounts
    jsondecode(file("${path.module}/account_list_workloads.json")), # Application/workload accounts
  )

  # Enrich account definitions with runtime values (account IDs from AWS)
  # This allows referencing account IDs in other configurations without hardcoding
  account_factory_list_enriched = [
    for account in local.account_factory_list : merge(account,
      {
        account_id = local.account_factory_all_account_ids[account.account_name]
      }
    )
  ]
}

# ===================================================================================================================
# IMPORTING EXISTING ACCOUNTS (Optional)
# ===================================================================================================================
# NOTE: To import existing AWS accounts into Account Factory management:
# import {
#   to = module.ntc_account_factory.aws_organizations_account.ntc_factory_account["INSERT_ACCOUNT_NAME"]
#   id = "123456789012" # Replace with existing AWS account ID
# }
# account also needs to be added to the account map (account_list JSON)
#
# ===================================================================================================================
# NTC ACCOUNT FACTORY MODULE
# ===================================================================================================================
# Central account vending machine for AWS Organizations
# ===================================================================================================================
module "ntc_account_factory" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory?ref=2.0.0"

  region = "eu-central-1"
  # -----------------------------------------------------------------------------------------------------------------
  # S3 BUCKETS - State and Artifact Storage
  # -----------------------------------------------------------------------------------------------------------------
  # ⚠️  S3 bucket names must be globally unique across ALL AWS accounts!
  # Replace "aws-c2" prefix with your organization's unique identifier
  # -----------------------------------------------------------------------------------------------------------------
  # BASELINE BUCKET: Terraform state, code, artifacts for account baselines
  account_factory_baseline_bucket_name = "aws-c2-ntc-af-baseline"

  # CLOUDTRAIL BUCKET: CloudTrail logs for lifecycle event triggers
  account_factory_cloudtrail_bucket_name = "aws-c2-ntc-af-cloudtrail"

  # -----------------------------------------------------------------------------------------------------------------
  # SERVICE QUOTAS - Increase Limits for Concurrent Operations
  # -----------------------------------------------------------------------------------------------------------------
  # Automatically request quota increases for Account Factory components
  # Setting to 0 uses AWS default quota (no increase requested)
  # Useful for: Large organizations with many accounts, parallel baseline deployments
  # -----------------------------------------------------------------------------------------------------------------
  increase_aws_service_quotas = {
    organizations_maximum_number_of_accounts = 20 # By default, Organizations is limited to 10 accounts
    codebuild_concurrent_runs_arm_small      = 20 # Increase for parallel baseline deployments
    codebuild_concurrent_runs_arm_large      = 0
    codebuild_concurrent_runs_linux_small    = 0 # Linux instances if not using ARM
    codebuild_concurrent_runs_linux_medium   = 0
    codebuild_concurrent_runs_linux_large    = 0
    codebuild_concurrent_runs_linux_2xlarge  = 0
    codepipelines_max_count                  = 0
    event_rules_max_count                    = 0
  }

  # -----------------------------------------------------------------------------------------------------------------
  # NAMING CONVENTIONS - Enforce Standards (Optional)
  # -----------------------------------------------------------------------------------------------------------------
  # ⚠️  CRITICAL: Account names and emails are Terraform resource identifiers!
  # Changing them in JSON will cause Terraform to CLOSE the old account and CREATE a new one.
  # While AWS Console allows renaming, Terraform treats name/email changes as replacements.
  # To rename: Manually update AWS Console + modify Terraform state (not recommended).
  # Best practice: Choose names carefully - they should be permanent.
  # -----------------------------------------------------------------------------------------------------------------
  account_factory_naming_conventions = {
    account_name_regex  = "^aws-c2-[a-z0-9-]+$" # Example: aws-c2-prod-app-001
    account_email_regex = "@nuvibit.com$"       # Must use organization domain
  }

  # -----------------------------------------------------------------------------------------------------------------
  # ACCOUNT LIST - Declarative Account Definitions from JSON/HCL
  # -----------------------------------------------------------------------------------------------------------------
  account_factory_list = local.account_factory_list

  # -----------------------------------------------------------------------------------------------------------------
  # NOTIFICATIONS - Alert on Lifecycle/Baseline Failures
  # -----------------------------------------------------------------------------------------------------------------
  account_factory_notification_settings = {
    org_identifier = "c2" # Organization identifier for notification subjects
    subscriptions = [
      {
        protocol  = "email"
        endpoints = ["operations+aws-c2@nuvibit.com"] # Replace with team distribution list
      }
    ]
  }

  # -----------------------------------------------------------------------------------------------------------------
  # BASELINE CREDENTIALS - Access Private Module Sources (Optional)
  # -----------------------------------------------------------------------------------------------------------------
  # ⚠️  WARNING: Never commit credentials to Git! Use variables from secure sources (e.g., vault, environment variables).
  # Required only if baseline references private Git repos or module registries
  # Reference: https://developer.hashicorp.com/terraform/language/modules/sources
  # -----------------------------------------------------------------------------------------------------------------
  account_baseline_git_ssh_key              = var.account_baseline_git_ssh_key
  account_baseline_github_access_token      = var.account_baseline_github_access_token
  account_baseline_terraform_registry_token = var.account_baseline_terraform_registry_token
  account_baseline_terraform_registry_host  = "spacelift.io"

  # ===================================================================================================================
  # ACCOUNT LIFECYCLE CUSTOMIZATION - Event-Driven Automation
  # ===================================================================================================================
  # Execute one-time Lambda-based automation triggered by AWS Organizations events
  # Templates defined in: 'ntc_account_factory_account_lifecycle_template.tf'
  # ===================================================================================================================
  account_lifecycle_customization_steps = [
    # -----------------------------------------------------------------------------------------------------------------
    # EVENT: CreateAccountResult - New Account Onboarding
    # -----------------------------------------------------------------------------------------------------------------
    # Triggered when: New AWS account successfully created via Organizations
    # Purpose: Automated onboarding and initial configuration
    # Execution: Lambda functions in Step Functions workflow (stateless, one-time)
    # -----------------------------------------------------------------------------------------------------------------
    {
      organizations_event_trigger = "CreateAccountResult"
      step_sequence = [
        # ---------------------------------------------------------------------------------------------------------
        # Custom Lifecycle Steps: Add your own Lambda-based automation
        # ---------------------------------------------------------------------------------------------------------
        # You can add custom steps by defining Lambda functions with organization-specific logic
        # Use cases: Custom notifications, internal system integration, specialized tagging, etc.
        # ---------------------------------------------------------------------------------------------------------
        # {
        #   step_name                  = "custom_account_setup"
        #   lambda_package_source_path = "${path.module}/lambda/custom_setup"  # Path to your Lambda code
        #   lambda_handler             = "main.lambda_handler"                 # Lambda handler function
        #   environment_variables = {
        #     "ORGANIZATIONS_MEMBER_ROLE" : "OrganizationAccountAccessRole"
        #     "CUSTOM_PARAMETER" : "custom_value"
        #   }
        # }
        # ---------------------------------------------------------------------------------------------------------
        # NTC Lifecycle Templates: Predefined templates from 'ntc_account_factory_account_lifecycle_template.tf'
        # Execute in this order (consider dependencies between steps):
        # ---------------------------------------------------------------------------------------------------------
        module.ntc_account_lifecycle_templates.account_lifecycle_customization_steps["enable_opt_in_regions"],  # 1. Enable regions first
        module.ntc_account_lifecycle_templates.account_lifecycle_customization_steps["delete_default_vpc"],     # 2. Remove default VPCs
        module.ntc_account_lifecycle_templates.account_lifecycle_customization_steps["increase_service_quota"], # 3. Raise quotas
        module.ntc_account_lifecycle_templates.account_lifecycle_customization_steps["tag_shared_resources"],   # 4. Tag RAM resources
        module.ntc_account_lifecycle_templates.account_lifecycle_customization_steps["create_account_alias"]    # 5. Set IAM alias
        # module.ntc_account_lifecycle_templates.account_lifecycle_customization_steps["enable_enterprise_support"], # Requires Enterprise Support Plan
      ]
    },
    # -----------------------------------------------------------------------------------------------------------------
    # EVENT: CloseAccountResult - Account Closure Handling
    # -----------------------------------------------------------------------------------------------------------------
    # Triggered when: AWS account closed via Organizations
    # Purpose: Quarantine closed accounts and prevent further activity
    # Execution: Move to suspended OU with restrictive SCPs
    # -----------------------------------------------------------------------------------------------------------------
    {
      organizations_event_trigger = "CloseAccountResult"
      step_sequence = [
        module.ntc_account_lifecycle_templates.account_lifecycle_customization_steps["move_to_suspended_ou"] # Isolate closed account
      ]
    }
  ]

  # -------------------------------------------------------------------------------------------------------------------
  # ON-DEMAND TRIGGERS - Manual Lifecycle Execution (Optional)
  # -------------------------------------------------------------------------------------------------------------------
  # Manually trigger lifecycle steps for specific accounts without waiting for actual events
  # Use cases:
  #   - Retroactively apply lifecycle to existing accounts
  #   - Re-run failed lifecycle steps
  #   - Test lifecycle templates in specific accounts
  # Reference: https://docs.aws.amazon.com/organizations/latest/userguide/orgs_cloudtrail-integration.html
  # -------------------------------------------------------------------------------------------------------------------
  account_lifecycle_customization_on_demand_triggers = {
    # user_defined_events = [
    #   jsonencode({
    #     "source" : "aws.organizations",
    #     "detail" : {
    #       "eventSource" : "organizations.amazonaws.com",
    #       "eventName" : "CreateAccountResult",
    #       "serviceEventDetails" : {
    #         "createAccountStatus" : {
    #           "state" : "SUCCEEDED",
    #           "accountId" : "INSERT_ACCOUNT_ID"
    #         }
    #       }
    #     }
    #   })
    # ]
  }

  # ===================================================================================================================
  # ACCOUNT BASELINE SCOPES - Continuous Governance Configuration
  # ===================================================================================================================
  # Define stateful Terraform-based configurations for different account groups
  # Templates defined in: 'ntc_account_factory_baseline_template.tf'
  # Each scope can have different baselines, regions, and targeting criteria
  # ===================================================================================================================
  account_baseline_scopes = [
    # =================================================================================================================
    # BASELINE SCOPE 1: CORE ACCOUNTS
    # =================================================================================================================
    # Purpose: Governance for core infrastructure accounts (management, security, networking, etc.)
    # Targeting: Accounts tagged with AccountType=core
    # =================================================================================================================
    {
      scope_name = "core-accounts"

      # -----------------------------------------------------------------------------------------------------------------
      # Terraform/OpenTofu Configuration
      # -----------------------------------------------------------------------------------------------------------------
      terraform_binary      = "opentofu" # Use opentofu or terraform
      terraform_parallelism = 10         # Reduce to avoid API rate limits
      terraform_version     = "1.10.7"   # https://github.com/opentofu/opentofu/releases
      aws_provider_version  = "6.25.0"   # https://registry.terraform.io/providers/hashicorp/aws

      # -----------------------------------------------------------------------------------------------------------------
      # Provider Default Tags - Applied to All Baseline Resources
      # -----------------------------------------------------------------------------------------------------------------
      provider_default_tags = {
        ManagedBy       = "ntc-account-factory",
        BaselineScope   = "core-accounts",
        BaselineVersion = "1.3.2" # you can define your own versioning scheme
      }

      # -----------------------------------------------------------------------------------------------------------------
      # Scheduled Execution - Drift Remediation
      # -----------------------------------------------------------------------------------------------------------------
      # Set > 0 to automatically rerun baseline for drift detection/remediation
      # Example: 24 = daily execution to fix manual changes
      # Set to 0 to disable scheduled runs (manual or on-change only)
      schedule_rerun_every_x_hours = 0
      # IAM role which exists in member accounts and can be assumed by baseline pipeline
      baseline_execution_role_name = "OrganizationAccountAccessRole"
      # session name used by baseline pipeline in member accounts
      baseline_execution_session_name = "ntc-account-factory"
      # (optional) additional providers which assume a specific account role for cross account orchestration
      # WARNING: removing an existing provider from 'baseline_assume_role_providers' can cause provider errors
      baseline_assume_role_providers = [
        {
          configuration_alias = "connectivity"
          role_arn            = local.ntc_parameters["connectivity"]["baseline_assume_role_arn"]
          session_name        = "ntc-account-factory"
        }
      ]
      # add terraform code to baseline from static files or dynamic templates
      baseline_terraform_files = [
        # {
        #   file_name = "baseline_openid_connect"
        #   content   = templatefile("${path.module}/files/account_baseline_example.tf", {})
        # },
        module.ntc_account_baseline_templates.account_baseline_terraform_files["iam_monitoring_reader"],
        module.ntc_account_baseline_templates.account_baseline_terraform_files["iam_instance_profile"],
        module.ntc_account_baseline_templates.account_baseline_terraform_files["oidc_spacelift"],
        module.ntc_account_baseline_templates.account_baseline_terraform_files["aws_config"],
      ]
      # add delay to pipeline to avoid errors on first run
      # in this case pipeline will wait for up to 10 minutes for dependencies to resolve
      pipeline_delay_options = {
        wait_for_seconds        = 120
        wait_retry_count        = 5
        wait_for_execution_role = true
        wait_for_regions        = true
      }
      # baseline terraform code will be provisioned in each specified region
      baseline_regions = ["us-east-1", "eu-central-1"]
      # baseline terraform code which can be provisioned in a single region (e.g. IAM)
      baseline_main_region = "eu-central-1"

      # -----------------------------------------------------------------------------------------------------------------
      # Baseline Parameters - Custom Configuration Data
      # -----------------------------------------------------------------------------------------------------------------
      # Pass custom parameters to baseline templates via var.baseline_parameters
      # Use for: environment-specific values, configuration data
      # -----------------------------------------------------------------------------------------------------------------
      baseline_parameters_json = jsonencode(
        {
          example_iam_role_name = "ntc-example-role" # Example custom parameter
        }
      )

      # -----------------------------------------------------------------------------------------------------------------
      # Resource Imports - Bring Existing Resources Under Baseline Management (Optional)
      # -----------------------------------------------------------------------------------------------------------------
      # Import existing resources to avoid recreation
      # Use import_condition_account_names to limit imports to specific accounts
      # -----------------------------------------------------------------------------------------------------------------
      baseline_import_resources = [
        {
          import_to                      = "module.baseline_eu_central_1[0].aws_iam_openid_connect_provider.ntc_oidc__nuvibit_app_spacelift_io[0]"
          import_id                      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/nuvibit.app.spacelift.io"
          import_condition_account_names = ["aws-c2-management"] # Only import in this account
        },
        {
          import_to                      = "module.baseline_eu_central_1[0].aws_iam_role.ntc_oidc__nuvibit_app_spacelift_io[0]"
          import_id                      = "ntc-oidc-spacelift-role"
          import_condition_account_names = ["aws-c2-management"] # Only import in this account
        },
      ]

      # -----------------------------------------------------------------------------------------------------------------
      # Account Targeting - Include Accounts in Baseline Scope
      # -----------------------------------------------------------------------------------------------------------------
      # Target accounts by: all, OU paths, names, or tags
      # Multiple criteria are OR'd together (union)
      # -----------------------------------------------------------------------------------------------------------------
      include_accounts_all         = false # Include all accounts (use with caution!)
      include_accounts_by_ou_paths = []    # Include by OU path: ["/root/production"]
      include_accounts_by_names    = []    # Include by name: ["aws-c2-prod-app"]
      include_accounts_by_tags = [         # Include by tag
        {
          key   = "AccountType"
          value = "core"
        }
      ]

      # -----------------------------------------------------------------------------------------------------------------
      # Account Exclusions - Remove Specific Accounts from Scope
      # -----------------------------------------------------------------------------------------------------------------
      # Exclusions are applied AFTER inclusions (higher priority)
      # -----------------------------------------------------------------------------------------------------------------
      exclude_accounts_by_ou_paths = [] # Exclude by OU path
      exclude_accounts_by_names    = [] # Exclude by name
      exclude_accounts_by_tags     = [] # Exclude by tag

      # -----------------------------------------------------------------------------------------------------------------
      # Decommissioning - Destroy Baseline Resources
      # -----------------------------------------------------------------------------------------------------------------
      # ⚠️  CRITICAL: Decommission resources BEFORE deleting the baseline scope!
      # Set to true/populate to destroy baseline resources in targeted accounts
      # -----------------------------------------------------------------------------------------------------------------
      decommission_accounts_all         = false # Decommission all accounts in scope
      decommission_accounts_by_ou_paths = []    # Decommission by OU path
      decommission_accounts_by_names    = []    # Decommission by name
      decommission_accounts_by_tags = [         # Decommission by tag (common pattern)
        {
          key   = "AccountDecommission"
          value = true
        }
      ]
    },
    # # =================================================================================================================
    # # BASELINE SCOPE 2: WORKLOAD ACCOUNTS - PROD
    # # =================================================================================================================
    # # Purpose: Governance for production application/workload accounts
    # # Targeting: Accounts in workload prod OUs (/root/workloads/prod)
    # # NOTE: update non-prod scope first to validate baseline configuration before applying to production accounts
    # # =================================================================================================================
    # {
    #   scope_name = "workload-accounts-prod"
    #   # NOTE: new unified baseline simplifies multi-region deployments using the new enhanced region support in AWS provider v6
    #   # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/enhanced-region-support
    #   # WARNING: existing baseline resources need to be migrated or redeployed to use the unified baseline
    #   unified_multi_region_baseline = true
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Terraform/OpenTofu Configuration
    #   # -----------------------------------------------------------------------------------------------------------------
    #   terraform_binary      = "opentofu" # Terraform or OpenTofu
    #   terraform_parallelism = 10         # Reduce to avoid API rate limits
    #   terraform_version     = "1.10.7"   # https://github.com/opentofu/opentofu/releases
    #   aws_provider_version  = "6.25.0"   # AWS provider version

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Provider Default Tags - Applied to All Baseline Resources
    #   # -----------------------------------------------------------------------------------------------------------------
    #   provider_default_tags = {
    #     ManagedBy       = "ntc-account-factory"
    #     BaselineScope   = "workload-accounts-prod"
    #     BaselineVersion = "2.0.0" # you can define your own versioning scheme
    #   }

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Scheduled Drift Remediation
    #   # -----------------------------------------------------------------------------------------------------------------
    #   schedule_rerun_every_x_hours = 0 # 0 = disabled, >0 = rerun every X hours
    #   # IAM role which exists in member accounts and can be assumed by baseline pipeline
    #   baseline_execution_role_name = "OrganizationAccountAccessRole"
    #   # session name used by baseline pipeline in member accounts
    #   baseline_execution_session_name = "ntc-account-factory"
    #   # (optional) additional providers which assume a specific account role for cross account orchestration
    #   # WARNING: removing an existing provider from 'baseline_assume_role_providers' can cause provider errors
    #   baseline_assume_role_providers = [
    #     {
    #       configuration_alias = "connectivity"
    #       role_arn            = local.ntc_parameters["connectivity"]["baseline_assume_role_arn"]
    #       session_name        = "ntc-account-factory"
    #     }
    #   ]
    #   # add terraform code to baseline from static files or dynamic templates
    #   baseline_terraform_files = [
    #     # {
    #     #   file_name = "baseline_openid_connect"
    #     #   content   = templatefile("${path.module}/files/account_baseline_example.tf", {})
    #     # },
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_iam_monitoring_reader"],
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_iam_instance_profile"],
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_oidc_spacelift"],
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_oidc_github"],
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_aws_config"],
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_tfstate_backend"],
    #   ]
    #   # add delay to pipeline to avoid errors on first run
    #   # in this case pipeline will wait for up to 10 minutes for dependencies to resolve
    #   pipeline_delay_options = {
    #     wait_for_seconds        = 120
    #     wait_retry_count        = 5
    #     wait_for_execution_role = true
    #     wait_for_regions        = true
    #   }
    #   # baseline terraform code will be provisioned in each specified region
    #   baseline_regions = ["us-east-1", "eu-central-1"]
    #   # baseline terraform code which can be provisioned in a single region (e.g. IAM)
    #   baseline_main_region = "eu-central-1"


    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Baseline Parameters - Custom Configuration Data
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Pass custom parameters to baseline templates via var.baseline_parameters
    #   # Use for: environment-specific values, configuration data
    #   # -----------------------------------------------------------------------------------------------------------------
    #   baseline_parameters_json = jsonencode(
    #     {
    #       example_iam_role_name = "ntc-example-role" # Example custom parameter
    #     }
    #   )

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Resource Imports - Bring Existing Resources Under Baseline Management (Optional)
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Import existing resources to avoid recreation
    #   # Use import_condition_account_names to limit imports to specific accounts
    #   # -----------------------------------------------------------------------------------------------------------------
    #   baseline_import_resources = [
    #     # {
    #     #   import_to                      = ""
    #     #   import_id                      = ""
    #     #   import_condition_account_names = []
    #     # }
    #   ]

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Account Targeting - Include Accounts in Baseline Scope
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Target by OU paths for workload accounts (prod, dev, test environments)
    #   # -----------------------------------------------------------------------------------------------------------------
    #   include_accounts_all = false # Don't include all accounts
    #   include_accounts_by_ou_paths = [
    #     "/root/workloads/prod", # Production workload accounts
    #   ]
    #   include_accounts_by_names = [] # Optional: specific account names
    #   include_accounts_by_tags  = [] # Optional: accounts with specific tags

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Account Exclusions - Remove Specific Accounts from Scope
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Exclusions applied after inclusions (higher priority)
    #   # -----------------------------------------------------------------------------------------------------------------
    #   exclude_accounts_by_ou_paths = [] # No OU exclusions
    #   exclude_accounts_by_names    = [] # Optional: exclude specific accounts
    #   exclude_accounts_by_tags     = [] # No tag exclusions

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Decommissioning - Destroy Baseline Resources
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # ⚠️  CRITICAL: Decommission resources BEFORE deleting the baseline scope!
    #   # Tag-based decommissioning is common pattern for workload accounts
    #   # -----------------------------------------------------------------------------------------------------------------
    #   decommission_accounts_all         = false # Don't decommission all
    #   decommission_accounts_by_ou_paths = []    # No OU-based decommissioning
    #   decommission_accounts_by_names    = []    # Optional: specific accounts
    #   decommission_accounts_by_tags = [         # Decommission by tag (common pattern)
    #     {
    #       key   = "AccountDecommission"
    #       value = true
    #     }
    #   ]
    # },
    # # =================================================================================================================
    # # BASELINE SCOPE 3: WORKLOAD ACCOUNTS - NON-PROD
    # # =================================================================================================================
    # # Purpose: Governance for non-production application/workload accounts
    # # Targeting: Accounts in workload non-prod OUs (/root/workloads/dev, /root/workloads/test)
    # # =================================================================================================================
    # {
    #   scope_name = "workload-accounts-non-prod"
    #   # NOTE: new unified baseline simplifies multi-region deployments using the new enhanced region support in AWS provider v6
    #   # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/enhanced-region-support
    #   # WARNING: existing baseline resources need to be migrated or redeployed to use the unified baseline
    #   unified_multi_region_baseline = true
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Terraform/OpenTofu Configuration
    #   # -----------------------------------------------------------------------------------------------------------------
    #   terraform_binary      = "opentofu" # Terraform or OpenTofu
    #   terraform_parallelism = 10         # Reduce to avoid API rate limits
    #   terraform_version     = "1.10.7"   # https://github.com/opentofu/opentofu/releases
    #   aws_provider_version  = "6.25.0"   # AWS provider version

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Provider Default Tags - Applied to All Baseline Resources
    #   # -----------------------------------------------------------------------------------------------------------------
    #   provider_default_tags = {
    #     ManagedBy       = "ntc-account-factory"
    #     BaselineScope   = "workload-accounts-non-prod"
    #     BaselineVersion = "2.0.0" # you can define your own versioning scheme
    #   }

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Scheduled Drift Remediation
    #   # -----------------------------------------------------------------------------------------------------------------
    #   schedule_rerun_every_x_hours = 0 # 0 = disabled, >0 = rerun every X hours
    #   # IAM role which exists in member accounts and can be assumed by baseline pipeline
    #   baseline_execution_role_name = "OrganizationAccountAccessRole"
    #   # session name used by baseline pipeline in member accounts
    #   baseline_execution_session_name = "ntc-account-factory"
    #   # (optional) additional providers which assume a specific account role for cross account orchestration
    #   # WARNING: removing an existing provider from 'baseline_assume_role_providers' can cause provider errors
    #   baseline_assume_role_providers = [
    #     {
    #       configuration_alias = "connectivity"
    #       role_arn            = local.ntc_parameters["connectivity"]["baseline_assume_role_arn"]
    #       session_name        = "ntc-account-factory"
    #     }
    #   ]
    #   # add terraform code to baseline from static files or dynamic templates
    #   baseline_terraform_files = [
    #     # {
    #     #   file_name = "baseline_openid_connect"
    #     #   content   = templatefile("${path.module}/files/account_baseline_example.tf", {})
    #     # },
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_iam_monitoring_reader"],
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_iam_instance_profile"],
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_oidc_spacelift"],
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_oidc_github"],
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_aws_config"],
    #     module.ntc_account_baseline_templates.account_baseline_terraform_files["unified_tfstate_backend"],
    #   ]
    #   # add delay to pipeline to avoid errors on first run
    #   # in this case pipeline will wait for up to 10 minutes for dependencies to resolve
    #   pipeline_delay_options = {
    #     wait_for_seconds        = 120
    #     wait_retry_count        = 5
    #     wait_for_execution_role = true
    #     wait_for_regions        = true
    #   }
    #   # baseline terraform code will be provisioned in each specified region
    #   baseline_regions = ["us-east-1", "eu-central-1"]
    #   # baseline terraform code which can be provisioned in a single region (e.g. IAM)
    #   baseline_main_region = "eu-central-1"


    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Baseline Parameters - Custom Configuration Data
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Pass custom parameters to baseline templates via var.baseline_parameters
    #   # Use for: environment-specific values, configuration data
    #   # -----------------------------------------------------------------------------------------------------------------
    #   baseline_parameters_json = jsonencode(
    #     {
    #       example_iam_role_name = "ntc-example-role" # Example custom parameter
    #     }
    #   )

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Resource Imports - Bring Existing Resources Under Baseline Management (Optional)
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Import existing resources to avoid recreation
    #   # Use import_condition_account_names to limit imports to specific accounts
    #   # -----------------------------------------------------------------------------------------------------------------
    #   baseline_import_resources = [
    #     # {
    #     #   import_to                      = ""
    #     #   import_id                      = ""
    #     #   import_condition_account_names = []
    #     # }
    #   ]

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Account Targeting - Include Accounts in Baseline Scope
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Target by OU paths for workload accounts (prod, dev, test environments)
    #   # -----------------------------------------------------------------------------------------------------------------
    #   include_accounts_all = false # Don't include all accounts
    #   include_accounts_by_ou_paths = [
    #     "/root/workloads/dev",  # Development workload accounts
    #     "/root/workloads/test", # Test workload accounts
    #   ]
    #   include_accounts_by_names = [] # Optional: specific account names
    #   include_accounts_by_tags  = [] # Optional: accounts with specific tags

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Account Exclusions - Remove Specific Accounts from Scope
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Exclusions applied after inclusions (higher priority)
    #   # -----------------------------------------------------------------------------------------------------------------
    #   exclude_accounts_by_ou_paths = [] # No OU exclusions
    #   exclude_accounts_by_names    = [] # Optional: exclude specific accounts
    #   exclude_accounts_by_tags     = [] # No tag exclusions

    #   # -----------------------------------------------------------------------------------------------------------------
    #   # Decommissioning - Destroy Baseline Resources
    #   # -----------------------------------------------------------------------------------------------------------------
    #   # ⚠️  CRITICAL: Decommission resources BEFORE deleting the baseline scope!
    #   # Tag-based decommissioning is common pattern for workload accounts
    #   # -----------------------------------------------------------------------------------------------------------------
    #   decommission_accounts_all         = false # Don't decommission all
    #   decommission_accounts_by_ou_paths = []    # No OU-based decommissioning
    #   decommission_accounts_by_names    = []    # Optional: specific accounts
    #   decommission_accounts_by_tags = [         # Decommission by tag (common pattern)
    #     {
    #       key   = "AccountDecommission"
    #       value = true
    #     }
    #   ]
    # },
  ]
}
