# ---------------------------------------------------------------------------------------------------------------------
# ¦ LOCALS
# ---------------------------------------------------------------------------------------------------------------------
locals {
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
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC ACCOUNT LIFECYCLE CUSTOMIZATION TEMPLATES
# ---------------------------------------------------------------------------------------------------------------------
module "accounf_lifecycle_templates" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-lifecycle-templates?ref=beta"

  account_lifecycle_customization_templates = local.account_factory_lifecycle_customization_templates
}