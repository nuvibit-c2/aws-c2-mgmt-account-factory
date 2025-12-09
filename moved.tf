moved {
  from = module.ntc_account_factory.aws_organizations_account.ntc_factory_account["aws-c2-hephaistos-dev"]
  to = module.ntc_account_factory.aws_organizations_account.ntc_factory_account["aws-c2-webshop-prod"]
}

moved {
  from = module.ntc_account_factory.aws_organizations_account.ntc_factory_account["aws-c2-portus-dev"]
  to = module.ntc_account_factory.aws_organizations_account.ntc_factory_account["aws-c2-webshop-test"]
}

moved {
  from = module.ntc_account_factory.aws_organizations_account.ntc_factory_account["aws-c2-apollo-dev"]
  to = module.ntc_account_factory.aws_organizations_account.ntc_factory_account["aws-c2-webshop-dev"]
}