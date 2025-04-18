<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.33 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 5.33 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_account_baseline_templates"></a> [account\_baseline\_templates](#module\_account\_baseline\_templates) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates | feat-sechub-cleanup |
| <a name="module_account_lifecycle_customization_templates"></a> [account\_lifecycle\_customization\_templates](#module\_account\_lifecycle\_customization\_templates) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-lifecycle-templates | 1.2.3 |
| <a name="module_ntc_account_factory"></a> [ntc\_account\_factory](#module\_ntc\_account\_factory) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory | fix-codebuild-credentials |
| <a name="module_ntc_parameters_bucket"></a> [ntc\_parameters\_bucket](#module\_ntc\_parameters\_bucket) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters | 1.1.2 |
| <a name="module_ntc_parameters_reader"></a> [ntc\_parameters\_reader](#module\_ntc\_parameters\_reader) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader | 1.1.2 |
| <a name="module_ntc_parameters_writer"></a> [ntc\_parameters\_writer](#module\_ntc\_parameters\_writer) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer | 1.1.2 |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.monitoring_reader](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_organizations_organization.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |
| [aws_region.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_baseline_git_ssh_key"></a> [account\_baseline\_git\_ssh\_key](#input\_account\_baseline\_git\_ssh\_key) | private key used in account baseline to copy modules with ssh | `string` | `"placeholder"` | no |
| <a name="input_account_baseline_github_access_token"></a> [account\_baseline\_github\_access\_token](#input\_account\_baseline\_github\_access\_token) | token used in account baseline to copy modules from github with https | `string` | `"placeholder"` | no |
| <a name="input_account_baseline_terraform_registry_token"></a> [account\_baseline\_terraform\_registry\_token](#input\_account\_baseline\_terraform\_registry\_token) | token used in account baseline to copy modules from terraform registry | `string` | `"placeholder"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | The current account id |
| <a name="output_default_region"></a> [default\_region](#output\_default\_region) | The default region name |
| <a name="output_ntc_account_factory_list"></a> [ntc\_account\_factory\_list](#output\_ntc\_account\_factory\_list) | Account Factory account list |
| <a name="output_ntc_parameters"></a> [ntc\_parameters](#output\_ntc\_parameters) | Map of all ntc parameters |
<!-- END_TF_DOCS -->