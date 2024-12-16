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

<!-- Account Lifecycle Customization -->
## Account Lifecycle Customization
Dynamic Lambda Step Functions manage the customized Account Lifecycle.<br>
Possible triggers for these Step Functions are AWS Organizations Events.<br>
Lambda Step Function can be tested manually by executing with an example event.<br>

### Example Event "CreateAccountResult" after creating a new AWS Account
```json
{
    "version": "0",
    "id": "68679d28-343e-d8ec-4a8c-cdd430223a5d",
    "detail-type": "AWS Service Event via CloudTrail",
    "source": "aws.organizations",
    "account": "111122223333",
    "time": "2023-05-15T08:27:14Z",
    "region": "us-east-1",
    "resources": [],
    "detail": {
        "eventVersion": "1.08",
        "userIdentity": {
            "accountId": "111122223333",
            "invokedBy": "AWS Internal"
        },
        "eventTime": "2023-05-15T08:26:57Z",
        "eventSource": "organizations.amazonaws.com",
        "eventName": "CreateAccountResult",
        "awsRegion": "us-east-1",
        "sourceIPAddress": "AWS Internal",
        "userAgent": "AWS Internal",
        "requestParameters": null,
        "responseElements": null,
        "eventID": "e5e20ada-7d1c-434d-bac2-32e156df4d93",
        "readOnly": false,
        "eventType": "AwsServiceEvent",
        "managementEvent": true,
        "recipientAccountId": "111122223333",
        "serviceEventDetails": {
            "createAccountStatus": {
                "id": "car-3fbd74c0f2fa11ed8b6e0a41b5dcf48f",
                "state": "SUCCEEDED",
                "accountName": "****",
                "accountId": "INSERT_ACCOUNT_ID",
                "requestedTimestamp": "May 15, 2023 8:26:54 AM",
                "completedTimestamp": "May 15, 2023 8:26:57 AM"
            }
        },
        "eventCategory": "Management"
    }
}
```

### Example Event "CloseAccountResult" after deleting an existing AWS Account
```json
{
    "version": "0",
    "id": "68679d28-343e-d8ec-4a8c-cdd430223a5d",
    "detail-type": "AWS Service Event via CloudTrail",
    "source": "aws.organizations",
    "account": "111122223333",
    "time": "2023-05-15T08:27:14Z",
    "region": "us-east-1",
    "resources": [],
    "detail": {
        "eventVersion": "1.08",
        "userIdentity": {
            "accountId": "111122223333",
            "invokedBy": "organizations.amazonaws.com"
        },
        "eventTime": "2022-03-18T18:17:06Z",
        "eventSource": "organizations.amazonaws.com",
        "eventName": "CloseAccountResult",
        "awsRegion": "us-east-1",
        "sourceIPAddress": "organizations.amazonaws.com",
        "userAgent": "organizations.amazonaws.com",
        "requestParameters": null,
        "responseElements": null,
        "eventID": "EXAMPLE8-90ab-cdef-fedc-ba987EXAMPLE",
        "readOnly": false,
        "eventType": "AwsServiceEvent",
        "managementEvent": true,
        "recipientAccountId": "111122223333",
        "serviceEventDetails": {
            "closeAccountStatus": {
                "accountId": "INSERT_ACCOUNT_ID",
                "state": "SUCCEEDED",
                "requestedTimestamp": "Mar 18, 2022 6:16:58 PM",
                "completedTimestamp": "Mar 18, 2022 6:16:58 PM"
            }
        },
        "eventCategory": "Management"
    }
}
```


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

Version: 1.3.0

### account\_lifecycle\_customization\_templates

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-lifecycle-templates

Version: 1.2.3

### ntc\_account\_factory

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory

Version: 1.8.2

### ntc\_parameters\_bucket

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters

Version: 1.1.3

### ntc\_parameters\_reader

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader

Version: 1.1.2

### ntc\_parameters\_writer

Source: github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer

Version: 1.1.2

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