<!-- BEGIN_TF_DOCS -->
## Requirements

The following requirements are needed by this module:

- terraform (>= 1.3.0)

- aws (~> 5.33)

## Providers

The following providers are used by this module:

- aws (~> 5.33)

## Modules

The following Modules are called:

### account\_baseline\_templates

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates

Version: 1.3.2

### ntc\_account\_factory

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory

Version: 1.11.0

### ntc\_account\_lifecycle\_templates

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-lifecycle-templates

Version: 1.3.0

### ntc\_parameters\_reader

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader

Version: 1.1.4

### ntc\_parameters\_writer

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer

Version: 1.1.4

## Resources

The following resources are used by this module:

- [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) (data source)
- [aws_iam_policy_document.monitoring_reader](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) (data source)
- [aws_organizations_organization.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) (data source)
- [aws_region.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) (data source)

## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### account\_baseline\_git\_ssh\_key

Description: private key used in account baseline to copy modules with ssh

Type: `string`

Default: `"placeholder"`

### account\_baseline\_github\_access\_token

Description: token used in account baseline to copy modules from github with https

Type: `string`

Default: `"placeholder"`

### account\_baseline\_terraform\_registry\_token

Description: token used in account baseline to copy modules from terraform registry

Type: `string`

Default: `"placeholder"`

## Outputs

The following outputs are exported:

### account\_id

Description: The current account id

### default\_region

Description: The default region name

### ntc\_account\_factory\_list

Description: Account Factory account list

### ntc\_parameters

Description: Map of all ntc parameters
<!-- END_TF_DOCS -->