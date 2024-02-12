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
| <a name="module_account_baseline_templates"></a> [account\_baseline\_templates](#module\_account\_baseline\_templates) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates | 1.2.0 |
| <a name="module_account_factory"></a> [account\_factory](#module\_account\_factory) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-factory | 1.4.0 |
| <a name="module_account_lifecycle_customization_templates"></a> [account\_lifecycle\_customization\_templates](#module\_account\_lifecycle\_customization\_templates) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-lifecycle-templates | 1.2.0 |
| <a name="module_ntc_parameters_bucket"></a> [ntc\_parameters\_bucket](#module\_ntc\_parameters\_bucket) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters | 1.1.0 |
| <a name="module_ntc_parameters_reader"></a> [ntc\_parameters\_reader](#module\_ntc\_parameters\_reader) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader | 1.1.1 |
| <a name="module_ntc_parameters_writer"></a> [ntc\_parameters\_writer](#module\_ntc\_parameters\_writer) | github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer | 1.1.1 |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_organizations_organization.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/organizations_organization) | data source |
| [aws_region.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_regions.enabled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/regions) | data source |

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