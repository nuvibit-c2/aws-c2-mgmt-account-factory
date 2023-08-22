# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
  # users and groups with global permissions for all accounts
  global_sso_permissions = {
    admin_groups = [
      "sg-aws-c2-admin"
    ]
    billing_groups = [
      "sg-aws-c2-billing"
    ]
    support_groups = [
      "sg-aws-c2-support"
    ]
  }

  # users that should be manually provisioned in IAM Identity Center via Terraform. Automatic provisioning must be disabled.
  # Users will not be synced back to external identitiy provider!
  sso_users = jsondecode(file("${path.module}/ntc_identity_center_users.json"))

  # groups that should be manually provisioned in IAM Identity Center via Terraform. Automatic provisioning must be disabled.
  # Groups will not be synced back to external identitiy provider!
  sso_groups = jsondecode(file("${path.module}/ntc_identity_center_groups.json"))

  # permissions sets which can be referenced for account assignments
  sso_permission_sets = [
    {
      name : "AdministratorAccess"
      description : "This permission set grants administrator access"
      session_duration : 2
      inline_policy_json : ""
      managed_policies : [
        {
          managed_by : "aws"
          policy_name : "AdministratorAccess"
          policy_path : "/"
        }
      ]
      boundary_policy : {}
    },
    {
      name : "Billing+ViewOnlyAccess"
      description : "This permission set grants billing and read-only access"
      session_duration : 10
      inline_policy_json : ""
      managed_policies : [
        {
          managed_by : "aws"
          policy_name : "Billing"
          policy_path : "/job-function/"
        },
        {
          managed_by : "aws"
          policy_name : "ViewOnlyAccess"
          policy_path : "/job-function/"
        }
      ]
      boundary_policy : {}
    },
    {
      name : "SupportUser+ReadOnlyAccess"
      description : "This permission set grants support and read-only access"
      session_duration : 10
      inline_policy_json : ""
      managed_policies : [
        {
          managed_by : "aws"
          policy_name : "SupportUser"
          policy_path : "/job-function/"
        },
        {
          managed_by : "aws"
          policy_name : "ReadOnlyAccess"
          policy_path : "/"
        }
      ]
      boundary_policy : {}
    }
  ]

  # account assignments can be done for individual accounts or an account map can be used for dynamic assigments
  sso_account_assignments = [
    for account in local.account_factory_list_enriched :
    {
      account_name = account.account_name
      account_id   = account.account_id
      permissions = [
        {
          permission_set_name : "AdministratorAccess"
          # combine global sso permissions and sso permissions from account map
          groups : concat(local.global_sso_permissions.admin_groups, account.customer_values.sso_admin_groups)
          # alternatively groups can also be dynamically associated via predefined naming
          # groups : ["sg-aws-admin-${account.account_id}"]
        },
        {
          permission_set_name : "Billing+ViewOnlyAccess"
          # combine global sso permissions and sso permissions from account map
          groups : concat(local.global_sso_permissions.billing_groups, account.customer_values.sso_billing_groups)
          # alternatively groups can also be dynamically associated via predefined naming
          # groups : ["sg-aws-billing-${account.account_id}"]
        },
        {
          permission_set_name : "SupportUser+ReadOnlyAccess"
          # combine global sso permissions and sso permissions from account map
          groups : concat(local.global_sso_permissions.support_groups, account.customer_values.sso_support_groups)
          # alternatively groups can also be dynamically associated via predefined naming
          # groups : ["sg-aws-support-${account.account_id}"]
        }
      ]
    }
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC IDENTITY CENTER - SSO
# ---------------------------------------------------------------------------------------------------------------------
module "identity_center" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-identity-center?ref=1.0.0"

  is_automatic_provisioning_enabled = false
  manual_provisioning_sso_users     = local.sso_users
  manual_provisioning_sso_groups    = local.sso_groups
  permission_sets                   = local.sso_permission_sets
  account_assignments               = local.sso_account_assignments

  providers = {
    aws = aws.euc1
  }
}