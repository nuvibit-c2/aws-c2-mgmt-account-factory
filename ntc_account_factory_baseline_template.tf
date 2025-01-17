# ---------------------------------------------------------------------------------------------------------------------
# ¦ DATA
# ---------------------------------------------------------------------------------------------------------------------
data "aws_iam_policy_document" "monitoring_reader" {
  statement {
    sid    = "CloudWatchReadOnlyAccessPermissions"
    effect = "Allow"
    actions = [
      "application-autoscaling:DescribeScalingPolicies",
      "application-signals:BatchGet*",
      "application-signals:Get*",
      "application-signals:List*",
      "autoscaling:Describe*",
      "cloudwatch:BatchGet*",
      "cloudwatch:Describe*",
      "cloudwatch:GenerateQuery",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "logs:Get*",
      "logs:List*",
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:Describe*",
      "logs:TestMetricFilter",
      "logs:FilterLogEvents",
      "logs:StartLiveTail",
      "logs:StopLiveTail",
      "oam:ListSinks",
      "sns:Get*",
      "sns:List*",
      "rum:BatchGet*",
      "rum:Get*",
      "rum:List*",
      "synthetics:Describe*",
      "synthetics:Get*",
      "synthetics:List*",
      "xray:BatchGet*",
      "xray:Get*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AWSXrayReadOnlyAccess"
    effect = "Allow"
    actions = [
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
      "xray:GetSamplingStatisticSummaries",
      "xray:BatchGetTraces",
      "xray:BatchGetTraceSummaryById",
      "xray:GetDistinctTraceGraphs",
      "xray:GetServiceGraph",
      "xray:GetTraceGraph",
      "xray:GetTraceSummaries",
      "xray:GetGroups",
      "xray:GetGroup",
      "xray:ListTagsForResource",
      "xray:ListResourcePolicies",
      "xray:GetTimeSeriesServiceStatistics",
      "xray:GetInsightSummaries",
      "xray:GetInsight",
      "xray:GetInsightEvents",
      "xray:GetInsightImpactGraph"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AmazonEC2ReadOnlyAccess"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
    ]
    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ¦ NTC ACCOUNT BASELINE TEMPLATES
# ---------------------------------------------------------------------------------------------------------------------
module "account_baseline_templates" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates?ref=1.3.2"

  # account baseline can either be defined by customer or consumed via template module
  # https://github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates
  account_baseline_templates = [
    {
      file_name     = "iam_monitoring_reader"
      template_name = "iam_role"
      iam_role_inputs = {
        role_name = "CloudWatch-CrossAccountSharingRole"
        # policy can be submitted directly as JSON or via data source aws_iam_policy_document
        policy_json         = data.aws_iam_policy_document.monitoring_reader.json
        role_principal_type = "AWS"
        # grant account (org management) permission to assume role in member account
        role_principal_identifiers = [local.account_factory_core_account_ids["aws-c2-management"]] # replace with monitoring account
      }
    },
    {
      file_name     = "iam_instance_profile"
      template_name = "iam_role"
      iam_role_inputs = {
        role_name = "ntc-ssm-instance-profile"
        # use 'policy_arn' to reference an aws managed policy
        policy_arn          = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        role_principal_type = "Service"
        # grant account (org management) permission to assume role in member account
        role_principal_identifiers = ["ec2.amazonaws.com"]
        # (optional) set to true to create an instance profile
        role_is_instance_profile = true
      }
    },
    {
      file_name     = "oidc_spacelift"
      template_name = "openid_connect"
      openid_connect_inputs = {
        provider                  = "nuvibit.app.spacelift.io"
        audience                  = "nuvibit.app.spacelift.io"
        role_name                 = "ntc-oidc-spacelift-role"
        role_path                 = "/"
        role_max_session_in_hours = 1
        permission_boundary_arn   = ""
        permission_policy_arn     = "arn:aws:iam::aws:policy/AdministratorAccess"
        # make sure to define a subject which is limited to your scope (e.g. a generic subject could grant access to all terraform cloud users)
        # you can use dynamic values by referencing the injected baseline variables (e.g. var.current_account_name) - additional '$' escape is required
        # for additional flexibility use 'subject_list_encoded' which allows injecting more complex structures (e.g. grant permission to multiple pipelines in one account)
        /* examples for common openid_connect subjects
          terraform cloud = "organization:ORG_NAME:project:PROJECT_NAME:workspace:WORKSPACE_NAME:run_phase:RUN_PHASE"
          spacelift       = "space:SPACE_ID:stack:STACK_ID:run_type:RUN_TYPE:scope:RUN_PHASE"
          gitlab          = "project_path:GROUP_NAME/PROJECT_NAME:ref_type:branch:ref:main"
          github          = "repo:ORG_NAME/REPO_NAME:environment:prod"
          jenkins         = "job:JOB_NAME/master"
        */
        # subject_list = ["space:aws-c2-01HMSG08P7X6MD11FYV831WN2B:stack:$${var.current_account_name}:*"]
        subject_list_encoded = <<EOT
flatten([
  [
    "space:aws-c2-01HMSG08P7X6MD11FYV831WN2B:stack:$${var.current_account_name}:*"
  ],
  [
    for subject in try(var.current_account_customer_values.additional_oidc_subjects, []) : "space:aws-c2-01HMSG08P7X6MD11FYV831WN2B:stack:$${subject}:*"
  ]
])
EOT
      }
    },
    {
      file_name     = "aws_config"
      template_name = "aws_config"
      aws_config_inputs = {
        config_log_archive_bucket_arn  = local.ntc_parameters["log-archive"]["log_bucket_arns"]["aws_config"]
        config_log_archive_kms_key_arn = local.ntc_parameters["log-archive"]["log_bucket_kms_key_arns"]["aws_config"]
        # optional inputs
        config_recorder_name         = "ntc-config-recorder"
        config_delivery_channel_name = "ntc-config-delivery"
        config_iam_role_name         = "ntc-config-role"
        config_iam_path              = "/"
        config_delivery_frequency    = "One_Hour"
        # (optional) override account baseline main region with main region of security tooling
        # this is necessary when security tooling uses a different main region
        # omit to use the main region of the account baseline
        config_security_main_region  = ""
      }
    },
  ]
}
