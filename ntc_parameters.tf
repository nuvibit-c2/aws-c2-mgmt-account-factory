locals {
  ntc_parameters_bucket_name = "aws-c2-ntc-parameters"
  ntc_parameters_writer_node = "mgmt-account-factory"

  # parameters that are managed by org management account
  ntc_parameters_to_write = {
    core_accounts = local.account_factory_core_account_ids
  }

  # by default existing node parameters will be merged with new parameters to avoid deleting parameters
  ntc_replace_parameters = true

  # node owner that is also the account factory can optionally store an account map
  ntc_store_account_map = true
  ntc_account_map = {
    for account in local.account_factory_list_enriched : account.account_id => account
  }

  # parameters are shared with parameter node owners by default and with the entire organization if org_id is specified
  share_parameters_with_entire_org = false

  # map of parameters merged from all parameter nodes
  ntc_parameters = {
    "account-factory": {
      "core_accounts": {
        "aws-c2-connectivity": "944538260333",
        "aws-c2-log-archive": "872327204802",
        "aws-c2-management": "228120440352",
        "aws-c2-security": "769269768678"
      }
    },
    "connectivity": {
      "customer_managed_prefix_lists": {
        "onprem-ipv4-ranges": {
          "address_family": "IPv4",
          "arn": "arn:aws:ec2:eu-central-1:944538260333:prefix-list/pl-055dcaa9a551fe6ad",
          "entries": [
            {
              "cidr": "192.168.10.0/24",
              "description": "Server Zone A"
            },
            {
              "cidr": "192.168.20.0/24",
              "description": "Server Zone B"
            },
            {
              "cidr": "192.168.30.0/24",
              "description": "Server Zone C"
            }
          ],
          "id": "pl-055dcaa9a551fe6ad",
          "max_entries": 3,
          "name": "onprem-ipv4-ranges",
          "version": 4
        }
      }
    },
    "identity-center": {},
    "log-archive": {
      "log_bucket_arns": {
        "aws_config": "arn:aws:s3:::aws-c2-config-archive",
        "dns_query_logs": "arn:aws:s3:::aws-c2-dns-query-logs-archive",
        "guardduty": "arn:aws:s3:::aws-c2-guardduty-archive",
        "org_cloudtrail": "arn:aws:s3:::aws-c2-cloudtrail-archive",
        "s3_access_logging": "arn:aws:s3:::aws-c2-access-logging",
        "vpc_flow_logs": "arn:aws:s3:::aws-c2-vpc-flow-logs-archive"
      },
      "log_bucket_ids": {
        "aws_config": "aws-c2-config-archive",
        "dns_query_logs": "aws-c2-dns-query-logs-archive",
        "guardduty": "aws-c2-guardduty-archive",
        "org_cloudtrail": "aws-c2-cloudtrail-archive",
        "s3_access_logging": "aws-c2-access-logging",
        "vpc_flow_logs": "aws-c2-vpc-flow-logs-archive"
      },
      "log_bucket_kms_key_arns": {
        "aws_config": "arn:aws:kms:eu-central-1:872327204802:key/a4b6e73b-e0bd-4987-91cd-fe5ab6632ab1",
        "dns_query_logs": "arn:aws:kms:eu-central-1:872327204802:key/1e90a551-0e2a-4e5c-885a-eca5e8fd1e77",
        "guardduty": "arn:aws:kms:eu-central-1:872327204802:key/c06137a0-1273-4d4b-9f0f-88e09aef5166",
        "org_cloudtrail": "arn:aws:kms:eu-central-1:872327204802:key/7acb498a-ad82-4952-9356-a8f51da82119",
        "vpc_flow_logs": "arn:aws:kms:eu-central-1:872327204802:key/2783eea5-e29b-49c7-909b-27bcef89f94a"
      }
    },
    "management": {
      "global": {
        "core_regions": [
          "eu-central-1",
          "eu-central-2"
        ],
        "workload_regions": [
          "eu-central-1",
          "eu-central-2"
        ]
      },
      "organization": {
        "org_id": "o-m29e8d9awz",
        "org_root_ou_id": "r-6gf5",
        "ou_ids": {
          "/root": "r-6gf5",
          "/root/infrastructure": "ou-6gf5-uktkya48",
          "/root/sandbox": "ou-6gf5-yvm8rkvb",
          "/root/security": "ou-6gf5-ebbpq9yb",
          "/root/suspended": "ou-6gf5-hyl8xkvz",
          "/root/workloads": "ou-6gf5-6ltp3mjf",
          "/root/workloads/dev": "ou-6gf5-1mp869fj",
          "/root/workloads/prod": "ou-6gf5-xrerrg1c",
          "/root/workloads/test": "ou-6gf5-5ejrrc90"
        }
      }
    },
    "security": {}
  }
  
  # module.ntc_parameters_reader.all_parameters
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC PARAMETERS - BUCKET (DEPLOY FIRST)
# ---------------------------------------------------------------------------------------------------------------------
module "ntc_parameters_bucket" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters?ref=1.1.0"

  force_destroy = false
  bucket_name   = local.ntc_parameters_bucket_name
  org_id        = local.share_parameters_with_entire_org ? data.aws_organizations_organization.current.id : ""
  # the ntc parameter bucket should ideally be created in same pipeline as account factory
  # all organization accounts are granted read permission for all parameters
  # only the parameter node owner account is granted write access to his corresponding parameters
  parameter_nodes = [
    {
      "node_name"                = "mgmt-organizations",
      "node_owner_account_id"    = local.account_factory_core_account_ids["aws-c2-management"]
      "node_owner_iam_role_name" = "ntc-oidc-spacelift-role"
    },
    {
      "node_name"                     = "mgmt-account-factory",
      "node_owner_account_id"         = local.account_factory_core_account_ids["aws-c2-management"]
      "node_owner_iam_role_name"      = "ntc-oidc-spacelift-role"
      "node_owner_is_account_factory" = true
    },
    {
      "node_name"                = "mgmt-identity-center",
      "node_owner_account_id"    = local.account_factory_core_account_ids["aws-c2-management"]
      "node_owner_iam_role_name" = "ntc-oidc-spacelift-role"
    },
    {
      "node_name"             = "connectivity"
      "node_owner_account_id" = local.account_factory_core_account_ids["aws-c2-connectivity"]
    },
    {
      "node_name"             = "security"
      "node_owner_account_id" = local.account_factory_core_account_ids["aws-c2-security"]
    },
    {
      "node_name"             = "log-archive"
      "node_owner_account_id" = local.account_factory_core_account_ids["aws-c2-log-archive"]
    }
  ]

  providers = {
    aws = aws.euc1
  }
}

# # ---------------------------------------------------------------------------------------------------------------------
# # ¦ NTC PARAMETERS - READER
# # ---------------------------------------------------------------------------------------------------------------------
# module "ntc_parameters_reader" {
#   source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/reader?ref=1.1.0"

#   bucket_name = local.ntc_parameters_bucket_name

#   providers = {
#     aws = aws.euc1
#   }
# }

# # ---------------------------------------------------------------------------------------------------------------------
# # ¦ NTC PARAMETERS - WRITER
# # ---------------------------------------------------------------------------------------------------------------------
# module "ntc_parameters_writer" {
#   source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-parameters//modules/writer?ref=1.1.0"

#   bucket_name        = local.ntc_parameters_bucket_name
#   parameter_node     = local.ntc_parameters_writer_node
#   node_parameters    = local.ntc_parameters_to_write
#   store_account_map  = local.ntc_store_account_map
#   account_map        = local.ntc_account_map
#   replace_parameters = local.ntc_replace_parameters

#   providers = {
#     aws = aws.euc1
#   }
# }