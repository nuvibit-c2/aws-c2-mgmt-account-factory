# existing resources can be imported to be managed by NTC - this can be usefull to avoid downtime or recreating critical resources
# import blocks are only available in Terraform v1.5.0 and later

/*
import {
  # the org management account must be initially created manually and needs to be imported
  to = module.ntc_account_factory.aws_organizations_account.ntc_factory_account["aws-c2-management"]
  id = "228120440352"
}
*/

moved {
  from = module.account_factory
  to   = module.ntc_account_factory
} 