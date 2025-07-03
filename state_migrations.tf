# existing resources can be imported to be managed by NTC - this can be usefull to avoid downtime or recreating critical resources
# import blocks are only available in Terraform v1.5.0 and later

/*
import {
  # the org management account must be initially created manually and needs to be imported
  to = module.ntc_account_factory.aws_organizations_account.ntc_factory_account["aws-c2-management"]
  id = "228120440352"
}
*/

removed {
  from = module.ntc_parameters_bucket.aws_s3_object.ntc_store_nodeowners
}

removed {
  from = module.ntc_parameters_bucket.aws_s3_bucket_versioning.ntc_parameters
}

removed {
  from = module.ntc_parameters_bucket.aws_s3_bucket_server_side_encryption_configuration.ntc_parameters
}

removed {
  from = module.ntc_parameters_bucket.aws_s3_bucket_public_access_block.ntc_parameters
}

removed {
  from = module.ntc_parameters_bucket.aws_s3_bucket_policy.ntc_parameters
}

removed {
  from = module.ntc_parameters_bucket.aws_s3_bucket_ownership_controls.ntc_parameters
}

removed {
  from = module.ntc_parameters_bucket.aws_s3_bucket.ntc_parameters
}
