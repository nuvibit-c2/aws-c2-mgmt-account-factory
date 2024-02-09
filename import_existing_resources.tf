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
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["global/aws-c2-0002"]
  id = "baseline_scope__global__aws-c2-0002__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["global/aws-c2-playground-test"]
  id = "baseline_scope__global__aws-c2-playground-test__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["global/aws-c2-connectivity"]
  id = "baseline_scope__global__aws-c2-connectivity__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["security-core/aws-c2-log-archive"]
  id = "baseline_scope__security-core__aws-c2-log-archive__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["global/aws-c2-log-archive"]
  id = "baseline_scope__global__aws-c2-log-archive__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["global/aws-c2-management"]
  id = "baseline_scope__global__aws-c2-management__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["workloads-prod/aws-c2-0001"]
  id = "baseline_scope__workloads-prod__aws-c2-0001__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["security-core/aws-c2-connectivity"]
  id = "baseline_scope__security-core__aws-c2-connectivity__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["global/aws-c2-security"]
  id = "baseline_scope__global__aws-c2-security__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["security-core/aws-c2-management"]
  id = "baseline_scope__security-core__aws-c2-management__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["global/aws-c2-0001"]
  id = "baseline_scope__global__aws-c2-0001__baseline.lock"
}
import {
  to = module.account_factory.aws_dynamodb_table.ntc_account_baseline_delete_protection["security-core/aws-c2-security"]
  id = "baseline_scope__security-core__aws-c2-security__baseline.lock"
}