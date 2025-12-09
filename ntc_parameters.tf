# =====================================================================================================================
# NTC PARAMETERS - CROSS-ACCOUNT CONFIGURATION SHARING
# =====================================================================================================================
# The NTC Parameters system provides a centralized, secure way to share configuration data across AWS accounts
# in your organization. Think of it as a distributed key-value store accessible to all accounts.
#
# WHY USE NTC PARAMETERS?
# -----------------------
# Problem: Terraform modules in different accounts need to reference outputs from other accounts
# 
# Traditional Solutions (and their problems):
#   ❌ Hardcode values: Not dynamic, breaks when resources change
#   ❌ AWS SSM Parameter Store: Complex cross-account access (requires assume role to write parameters)
#   ❌ Terraform remote state: Tight coupling, security concerns with state file access
#   ❌ Manual coordination: Error-prone, doesn't scale
#
# NTC Parameters Solution:
#   ✅ Centralized S3 bucket stores all parameters
#   ✅ Each account writes to its own "parameter node" (namespace)
#   ✅ All organization accounts can read all parameters
#   ✅ No circular dependencies or tight coupling
#   ✅ Automatic drift detection and updates
#
# HOW IT WORKS:
# -------------
# 1. Management account creates S3 bucket with organization-wide read access
# 2. Each account writes its outputs to a dedicated parameter node:
#    - mgmt-organizations → org_id, ou_ids, etc.
#    - connectivity → vpc_ids, subnet_ids, transit_gateway_id
#    - log-archive → s3_bucket_name, kms_key_arn
# 3. Any account reads parameters using the reader module
# 4. Parameters are referenced via: local.ntc_parameters["node-name"]["key"]
# =====================================================================================================================

# ---------------------------------------------------------------------------------------------------------------------
# LOCAL VARIABLES - ACCOUNT FACTORY PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # -------------------------------------------------------------------------------------------------------------------
  # S3 Bucket Name
  # -------------------------------------------------------------------------------------------------------------------
  # Centralized parameter storage bucket (created by mgmt-organizations)
  # ⚠️  Must match the bucket name across all accounts in the organization
  # -------------------------------------------------------------------------------------------------------------------
  ntc_parameters_bucket_name = "aws-c2-ntc-parameters"

  # -------------------------------------------------------------------------------------------------------------------
  # Parameter Node Name
  # -------------------------------------------------------------------------------------------------------------------
  # This account's namespace in the parameter bucket
  # Convention: <account-type>-<account-purpose>
  # -------------------------------------------------------------------------------------------------------------------
  ntc_parameters_writer_node = "mgmt-account-factory"

  # -----------------------------------------------------
  # PARAMETERS TO WRITE - Account Factory Outputs
  # -----------------------------------------------------
  # These parameters are consumed by virtually every account in the organization
  # Changes here affect all downstream accounts - coordinate updates carefully
  # -----------------------------------------------------
  ntc_parameters_to_write = {
    # Map of core account names to account IDs
    # Usage: local.ntc_parameters["mgmt-account-factory"]["core_accounts"]["INSERT_ACCOUNT_NAME"]
    # Updates: Automatically reflects new core accounts added to account factory
    "core_accounts" = local.account_factory_core_account_ids

    # Map of IAM role ARNs which are used by the account baseline to manage member accounts
    # Usage: local.ntc_parameters["mgmt-account-factory"]["baseline_role_arns"]
    # Updates: Changes when baseline scopes are added/removed
    "baseline_role_arns" = module.ntc_account_factory.account_factory_baseline_iam_role_arns
  }

  # -----------------------------------------------------
  # ACCOUNT MAP - Comprehensive Account Inventory
  # -----------------------------------------------------
  # Special feature for Account Factory: Store complete account metadata
  # This enables account discovery without calling AWS Organizations API
  # 
  # WHAT'S INCLUDED:
  #   - account_id, account_name, account_email
  #   - ou_path
  #   - account_tags
  #   - status
  #
  # USE CASES:
  #   - Automation: Iterate over all accounts matching criteria
  #   - Dashboards: Display account inventory
  #   - Compliance: Audit account configuration
  #   - Cost allocation: Map costs to business units
  #   - Security scanning: Target all production accounts
  # -----------------------------------------------------
  ntc_account_map = {
    for account in local.account_factory_list_enriched : account.account_id => account
  }

  # -----------------------------------------------------
  # PARAMETERS TO READ - From All Parameter Nodes
  # -----------------------------------------------------
  # Access parameters from any account in the organization
  # Examples:
  #   - local.ntc_parameters["mgmt-organizations"]["org_id"]
  #   - local.ntc_parameters["connectivity"]["transit_gateway_id"]
  #   - local.ntc_parameters["log-archive"]["cloudtrail_bucket"]["bucket_id"]
  # -----------------------------------------------------
  ntc_parameters = module.ntc_parameters_reader.all_parameters
}

# =====================================================================================================================
# NTC PARAMETERS READER - READ PARAMETERS FROM ALL NODES
# =====================================================================================================================
# Reads and merges parameters from ALL parameter nodes in the S3 bucket
#
# WHAT THIS MODULE DOES:
# ----------------------
# 1. Lists all objects in the S3 bucket (all parameter nodes)
# 2. Downloads and parses each parameter node's JSON file
# 3. Merges all parameters into a single map structure
# 4. Makes them available via: 'module.ntc_parameters_reader.all_parameters'
#
# OUTPUT STRUCTURE:
# -----------------
# {
#   "mgmt-organizations" = {
#     "org_id" = "o-xxxxx",
#     "ou_ids" = {...}
#   },
#   "connectivity" = {
#     "vpc_id" = "vpc-xxxxx",
#     "subnet_ids" = [...]
#   },
#   "security-tooling" = {
#     "guardduty_detector_id" = "xxxxx"
#   }
# }
#
# USAGE EXAMPLES:
# ---------------
# Access organization ID:
#   local.ntc_parameters["mgmt-organizations"]["org_id"]
#
# Access Transit Gateway ID from connectivity account:
#   local.ntc_parameters["connectivity"]["transit_gateway_id"]
#
# Access core account IDs:
#   local.ntc_parameters["mgmt-account-factory"]["core_accounts"]["INSERT_ACCOUNT_NAME"]
# =====================================================================================================================
module "ntc_parameters_reader" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=1.1.4"

  bucket_name = local.ntc_parameters_bucket_name

  providers = {
    aws = aws.euc1
  }
}

# =====================================================================================================================
# NTC PARAMETERS WRITER - WRITE THIS ACCOUNT'S PARAMETERS
# =====================================================================================================================
# Writes this account's parameters to its dedicated parameter node in the S3 bucket
#
# WHAT THIS MODULE DOES:
# ----------------------
# 1. Takes parameters from node_parameters input
# 2. Converts them to JSON format
# 3. Writes to S3: s3://<bucket>/<parameter_node>/parameters.json
# 4. Other accounts can immediately read the updated parameters
#
# WRITE PERMISSIONS:
# ------------------
# This account can ONLY write to its own parameter node (mgmt-organizations)
# Attempting to write to another node will fail with S3 AccessDenied
#
# REPLACE_PARAMETERS BEHAVIOR:
# ----------------------------
# replace_parameters = true (RECOMMENDED):
#   • Completely replaces the parameter node content on each run
#   • Ensures parameters stay in sync with Terraform state
#   • Removes any manually added parameters
#   • Prevents parameter drift
#
# replace_parameters = false:
#   • Merges new parameters with existing ones
#   • Manually added parameters are preserved
#   • Risk of stale parameters accumulating over time
#   • Use only if you need to manually manage some parameters
#
# WRITE TIMING:
# -------------
# ⚠️  Parameters are written AFTER all resources are created
# ⚠️  Other accounts may see stale parameters until this run completes
#
# WHAT TO WRITE:
# --------------
# DO write:
#   ✓ Resource IDs (VPC IDs, subnet IDs, account IDs)
#   ✓ ARNs (KMS keys, SNS topics, IAM roles)
#   ✓ Configuration values (CIDR blocks, region lists)
#   ✓ Non-sensitive metadata
#
# DO NOT write:
#   ✗ Secrets, passwords, API keys (use AWS Secrets Manager instead)
#   ✗ Sensitive data (use proper secrets management)
#   ✗ Frequently changing data (use SSM Parameter Store for dynamic values)
#   ✗ Large binary data (parameters should be small JSON-serializable values)
# =====================================================================================================================
module "ntc_parameters_writer" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer?ref=1.1.4"

  bucket_name        = local.ntc_parameters_bucket_name # S3 bucket for parameter storage
  parameter_node     = local.ntc_parameters_writer_node # This account's namespace
  node_parameters    = local.ntc_parameters_to_write    # Parameters to write
  replace_parameters = true                             # Always replace (prevent drift)

  # Account Factory Special Feature: Store comprehensive account inventory
  store_account_map = true                  # Enable account map storage
  account_map       = local.ntc_account_map # Complete account inventory

  providers = {
    aws = aws.euc1
  }
}