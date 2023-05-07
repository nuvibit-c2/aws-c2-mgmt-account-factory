# Terraform workspace repository for aws-c2-account-factory

<!-- LOGO -->
<a href="https://nuvibit.com">
    <img src="https://nuvibit.com/images/logo/logo-nuvibit-square.png" alt="nuvibit logo" title="nuvibit" align="right" width="100" />
</a>

<!-- SHIELDS -->
[![Maintained by nuvibit.com][nuvibit-shield]][nuvibit-url]
[![Terraform Version][terraform-version-shield]][terraform-version-url]

<!-- DESCRIPTION -->
[Terraform workspace][terraform-workspace-url] repository to provision and manage the NTC Account Factory

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.64.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_account_factory"></a> [account\_factory](#module\_account\_factory) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory | beta |
| <a name="module_identity_center"></a> [identity\_center](#module\_identity\_center) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-identity-center | beta |
| <a name="module_ntc_parameters_bucket"></a> [ntc\_parameters\_bucket](#module\_ntc\_parameters\_bucket) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters | beta |
| <a name="module_ntc_parameters_reader"></a> [ntc\_parameters\_reader](#module\_ntc\_parameters\_reader) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader | beta |
| <a name="module_ntc_parameters_writer"></a> [ntc\_parameters\_writer](#module\_ntc\_parameters\_writer) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer | beta |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_organizations_organization.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |
| [aws_region.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_account_id"></a> [account\_id](#output\_account\_id) | The current account id |
| <a name="output_default_region"></a> [default\_region](#output\_default\_region) | The default region name |
| <a name="output_ntc_parameters"></a> [ntc\_parameters](#output\_ntc\_parameters) | Map of all ntc parameters |
<!-- END_TF_DOCS -->

<!-- AUTHORS -->
## Authors
This repository is maintained by [Nuvibit][nuvibit-url] with help from [these amazing contributors][contributors-url]

<!-- COPYRIGHT -->
<br />
<br />
<p align="center">Copyright &copy; 2023 Nuvibit AG</p>

<!-- MARKDOWN LINKS & IMAGES -->
[nuvibit-shield]: https://img.shields.io/badge/maintained%20by-nuvibit.com-%235849a6.svg?style=flat&color=1c83ba
[nuvibit-url]: https://nuvibit.com
[terraform-version-shield]: https://img.shields.io/badge/terraform-%3E%3D1.3-blue.svg?style=flat&color=blueviolet
[terraform-version-url]: https://developer.hashicorp.com/terraform/language/v1.3.x/upgrade-guides
[contributors-url]: https://github.com/nuvibit-terraform-collection/aws-c2-account-factory/graphs/contributors
[terraform-workspace-url]: https://app.terraform.io/app/nuvibit-c2/workspaces/aws-c2-account-factory