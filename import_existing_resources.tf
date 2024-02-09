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
  to = module.account_factory.aws_iam_role.ntc_baseline_pipeline_role["security-core"]
  id = "ntc-af-pipeline-role__security-core"
}
import {
  to = module.account_factory.aws_iam_role.ntc_baseline_pipeline_role["global"]
  id = "ntc-af-pipeline-role__global"
}
import {
  to = module.account_factory.aws_iam_role.ntc_baseline_pipeline_role["workloads-prod"]
  id = "ntc-af-pipeline-role__workloads-prod"
}
import {
  to = module.account_factory.aws_iam_role.ntc_baseline_pipeline_event_rule_role
  id = "ntc-af-pipeline-trigger-role"
}
import {
  to = module.account_factory.module.account_factory_cloudtrail.aws_cloudtrail.ntc_org_events_trail
  id = "ntc-af-org-events-trail"
}
import {
  to = module.account_factory.module.lambda_pretty_notifications.aws_lambda_function.ntc_lambda
  id = "ntc-af-notification-lambda"
}
import {
  to = module.account_factory.module.lambda_step_function["on_CreateAccountResult_invite_security_members"].aws_lambda_function.ntc_lambda
  id = "on_CreateAccountResult_invite_security_members"
}
import {
  to = module.account_factory.module.lambda_step_function["on_CreateAccountResult_enable_opt_in_regions"].aws_lambda_function.ntc_lambda
  id = "on_CreateAccountResult_enable_opt_in_regions"
}
import {
  to = module.account_factory.module.lambda_step_function["on_CreateAccountResult_tag_shared_resources"].aws_lambda_function.ntc_lambda
  id = "on_CreateAccountResult_tag_shared_resources"
}
import {
  to = module.account_factory.module.lambda_step_function["on_CloseAccountResult_move_to_suspended_ou"].aws_lambda_function.ntc_lambda
  id = "on_CloseAccountResult_move_to_suspended_ou"
}
import {
  to = module.account_factory.module.lambda_step_function["on_CreateAccountResult_increase_service_quota"].aws_lambda_function.ntc_lambda
  id = "on_CreateAccountResult_increase_service_quota"
}
import {
  to = module.account_factory.module.lambda_step_function["on_CreateAccountResult_delete_default_vpc"].aws_lambda_function.ntc_lambda
  id = "on_CreateAccountResult_delete_default_vpc"
}