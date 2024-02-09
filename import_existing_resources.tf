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
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["workloads-prod/aws-c2-0001"]
  id = "ntc-af_workloads-prod_aws-c2-0001"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["global/aws-c2-0002"]
  id = "ntc-af_global_aws-c2-0002"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["security-core/aws-c2-management"]
  id = "ntc-af_security-core_aws-c2-management"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["global/aws-c2-log-archive"]
  id = "ntc-af_global_aws-c2-log-archive"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["security-core/aws-c2-connectivity"]
  id = "ntc-af_security-core_aws-c2-connectivity"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["global/aws-c2-management"]
  id = "ntc-af_global_aws-c2-management"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["global/aws-c2-0001"]
  id = "ntc-af_global_aws-c2-0001"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["global/aws-c2-security"]
  id = "ntc-af_global_aws-c2-security"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["global/aws-c2-connectivity"]
  id = "ntc-af_global_aws-c2-connectivity"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["security-core/aws-c2-security"]
  id = "ntc-af_security-core_aws-c2-security"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["security-core/aws-c2-log-archive"]
  id = "ntc-af_security-core_aws-c2-log-archive"
}
import {
  to = module.account_factory.aws_codepipeline.ntc_baseline_pipeline["global/aws-c2-playground-test"]
  id = "ntc-af_global_aws-c2-playground-test"
}