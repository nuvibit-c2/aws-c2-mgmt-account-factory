/*
NTC Account Factory - Unified Account Baseline Template
========================================================
This template uses the unified baseline model (AWS provider >= 6.0) which supports
the region attribute for multi-region deployments from a single root module.

Available injected variables:

var.aws_partition (string)
var.aws_partition_dns_suffix (string)
var.main_region (string)
var.baseline_regions (list(string))
var.current_account_id (string)
var.current_account_name (string)
var.current_account_email (string)
var.current_account_ou_path (string)
var.current_account_tags (map)
var.current_account_alternate_contacts (list)
var.current_account_customer_values (any)
var.baseline_scope_name (string)
var.baseline_parameters (any)
var.baseline_terraform_version (string)
var.baseline_terraform_binary (string)
var.baseline_aws_provider_version (string)
var.baseline_execution_role_name (string)
*/


# ---------------------------------------------------------------------------------------------------------------------
# ¦ UNIFIED BASELINE - SHIELD ADVANCED SUBSCRIPTION (GLOBAL)
# ---------------------------------------------------------------------------------------------------------------------
# Some global resources don't support the 'region' attribute but need to be deployed in the global service region (us-east-1 for standard aws partition).
# You can use the 'global_service_region' provider alias instead
resource "aws_shield_subscription" "advanced" {
  # WARNING: This resource creates a subscription to AWS Shield Advanced, which requires a 1 year subscription commitment with a monthly fee
  # remove 'count = 0' to enable the resource and create the subscription
  count = 0

  auto_renew = "ENABLED"

  provider = aws.global_service_region
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ UNIFIED BASELINE - IAM PASSWORD POLICY (GLOBAL)
# ---------------------------------------------------------------------------------------------------------------------
# IAM is a global service - no for_each/region needed, deploy once per account.
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ UNIFIED BASELINE - S3 ACCOUNT PUBLIC ACCESS BLOCK (GLOBAL)
# ---------------------------------------------------------------------------------------------------------------------
# Block all public access to S3 buckets at the account level
resource "aws_s3_account_public_access_block" "block_public" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ UNIFIED BASELINE - EBS DEFAULT ENCRYPTION (REGIONAL)
# ---------------------------------------------------------------------------------------------------------------------
# Enable EBS encryption by default in every baseline region.
resource "aws_ebs_encryption_by_default" "enabled" {
  for_each = toset(var.baseline_regions)

  region  = each.value
  enabled = true
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ UNIFIED BASELINE - IMDSv2 ENFORCEMENT (REGIONAL)
# ---------------------------------------------------------------------------------------------------------------------
# Enforce IMDSv2 for all new EC2 instances by setting the account-level default.
resource "aws_ec2_instance_metadata_defaults" "imdsv2" {
  for_each = toset(var.baseline_regions)

  region                           = each.value
  http_tokens                      = "required"
  http_put_response_hop_limit      = 2
  instance_metadata_tags           = "disabled"
  http_endpoint                    = "enabled"
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ UNIFIED BASELINE - SNS ALERTING TOPIC (REGIONAL)
# ---------------------------------------------------------------------------------------------------------------------
# Create an SNS topic for security/operational alerts in every region.
# Demonstrates using injected account variables in resource configuration.
resource "aws_sns_topic" "baseline_alerts" {
  for_each = toset(var.baseline_regions)

  region = each.value
  name   = "$${var.current_account_name}-baseline-alerts"
}


# ---------------------------------------------------------------------------------------------------------------------
# ¦ UNIFIED BASELINE - CLOUDWATCH LOG GROUP (REGIONAL)
# ---------------------------------------------------------------------------------------------------------------------
# Create a centralized log group in every region for baseline workloads.
resource "aws_cloudwatch_log_group" "baseline" {
  for_each = toset(var.baseline_regions)

  region            = each.value
  name              = "/baseline/$${var.current_account_name}"
  retention_in_days = 365
}
