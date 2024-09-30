# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC ACCOUNT LIFECYCLE CUSTOMIZATION TEMPLATES
# ---------------------------------------------------------------------------------------------------------------------
module "account_lifecycle_customization_templates" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-lifecycle-templates?ref=1.2.3"

  # customization steps can either be defined by customer or consumed via template module
  # https://github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-lifecycle-templates
  account_lifecycle_customization_templates = [
    {
      template_name               = "enable_opt_in_regions"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
      opt_in_regions              = ["eu-central-2"]
    },
    {
      template_name               = "delete_default_vpc"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
    },
    {
      template_name               = "increase_service_quota"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
      quota_increases = [
        {
          # global quotas are in us-east-1
          region       = "us-east-1"
          quota_name   = "Managed policies per role"
          service_code = "iam"
          value        = 20
        }
      ]
    },
    {
      template_name               = "tag_shared_resources"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
      shared_resources_regions    = ["eu-central-1", "eu-central-2"]
    },
    {
      template_name               = "move_to_suspended_ou"
      organizations_event_trigger = "CloseAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
      suspended_ou_id             = try(local.ntc_parameters["mgmt-organizations"]["ou_ids"]["/root/suspended"], "")
    },
    # {
    #   template_name               = "invite_security_members"
    #   organizations_event_trigger = "CreateAccountResult"
    #   organizations_member_role   = "OrganizationAccountAccessRole"
    #   security_regions            = local.all_enabled_regions
    #   security_member_of = {
    #     securityhub = true
    #     guardduty   = true
    #     inspector   = true
    #   }
    # },
  ]
}