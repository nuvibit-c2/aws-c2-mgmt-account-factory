# existing resources can be imported to be managed by NTC - this can be usefull to avoid downtime or recreating critical resources
# import blocks are only available in Terraform v1.5.0 and later

/*
import {
  # the org management account must be initially created manually and needs to be imported
  to = module.account_factory.aws_organizations_account.ntc_factory_account["aws-c2-management"]
  id = "228120440352"
}
*/

import {
  to = module.account_factory.aws_organizations_account.ntc_factory_account["aws-c2-log-archive"]
  id = "872327204802"
}
import {
  to = module.account_factory.aws_organizations_account.ntc_factory_account["aws-c2-security"]
  id = "769269768678"
}
import {
  to = module.account_factory.aws_organizations_account.ntc_factory_account["aws-c2-0002"]
  id = "090258021222"
}
import {
  to = module.account_factory.aws_organizations_account.ntc_factory_account["aws-c2-management"]
  id = "228120440352"
}
import {
  to = module.account_factory.aws_organizations_account.ntc_factory_account["aws-c2-playground-test"]
  id = "143858593822"
}
import {
  to = module.account_factory.aws_organizations_account.ntc_factory_account["aws-c2-connectivity"]
  id = "944538260333"
}
import {
  to = module.account_factory.aws_organizations_account.ntc_factory_account["aws-c2-0001"]
  id = "945766593056"
}
import {
  to = module.account_factory.aws_iam_role.ntc_lambda_execution_role
  id = "ntc-af-lambda-execution-role"
}
import {
  to = module.account_factory.aws_kms_alias.ntc_account_factory_encryption
  id = "alias/ntc-af-encryption"
}
import {
  to = module.account_factory.aws_iam_role.ntc_state_machine_event_rule_role
  id = "ntc-af-event-forwarding-role-trigger-role"
}
import {
  to = module.ntc_parameters_bucket.aws_s3_bucket.ntc_parameters
  id = "aws-c2-ntc-parameters"
}
import {
  to = module.account_factory.module.baseline_artifacts_bucket.aws_s3_bucket.ntc_bucket
  id = "aws-c2-ntc-af-baseline-artifacts"
}
import {
  to = module.account_factory.module.baseline_bucket.aws_s3_bucket.ntc_bucket
  id = "aws-c2-ntc-af-baseline"
}
import {
  to = module.account_factory.module.account_factory_cloudtrail.module.cloudtrail_bucket.aws_s3_bucket.ntc_bucket
  id = "aws-c2-ntc-af-cloudtrail"
}
import {
  to = module.account_factory.module.account_factory_cloudtrail.aws_kms_alias.ntc_cloudtrail_encryption
  id = "alias/ntc-af-cloudtrail-encryption"
}
import {
  to = module.account_factory.module.account_factory_cloudtrail.aws_iam_role.ntc_event_bus_forward[0]
  id = "ntc-af-event-forwarding-role"
}