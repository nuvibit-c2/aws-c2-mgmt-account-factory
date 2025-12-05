# =====================================================================================================================
# NTC ACCOUNT BASELINE TEMPLATES - STATEFUL ACCOUNT GOVERNANCE
# =====================================================================================================================
# Establish and maintain consistent configurations, guardrails, and security controls across AWS accounts
#
# PURPOSE OF BASELINE TEMPLATES:
# -------------------------------
# Account Baseline is designed for ONGOING, STATEFUL governance that maintains the desired state
# of your AWS accounts through CI/CD pipelines and Terraform. These are managed configurations that:
#
#   ✓ Maintain Terraform state for drift detection and remediation
#   ✓ Execute on schedules or on-demand to enforce compliance
#   ✓ Apply comprehensive security and governance controls
#   ✓ Continuously reconcile actual state with desired state
#   ✓ Support updates and version evolution over time
#   ✓ Ideal for resources requiring ongoing management and monitoring
#
# BASELINE vs. LIFECYCLE (Key Differences):
# ------------------------------------------
#   Account Baseline:                     | Account Lifecycle:
#   • CI/CD-driven (proactive)            | • Event-driven (reactive)
#   • Continuous management               | • One-time execution
#   • Stateful (tracked in Terraform)     | • Stateless (no Terraform state)
#   • Terraform-based configuration       | • Lambda-based automation
#   • Comprehensive governance            | • Fast, targeted operations
#   • Drift detection and remediation     | • "Set it and forget it"
#   • Scheduled or on-demand execution    | • Event-triggered execution
#
# WHEN TO USE BASELINE (vs. LIFECYCLE):
# --------------------------------------
#   Use Baseline for:                     | Use Lifecycle for:
#   ✓ IAM roles and policies              | ✓ Enable opt-in regions
#   ✓ Security baselines (AWS Config)     | ✓ Delete default VPCs
#   ✓ Networking baseline (VPC, Route53)  | ✓ Increase service quotas
#   ✓ Cross-account access roles          | ✓ Configure Enterprise Support
#   ✓ OIDC providers for CI/CD            | ✓ Create IAM account alias
#   ✓ Any resource needing updates        | ✓ One-time setup tasks
#   ✓ Resources requiring drift detection | ✓ Irreversible actions
#
# WHAT ARE BASELINE TEMPLATES?
# -----------------------------
# Baseline templates are Terraform configurations deployed via NTC Account Factory that:
#   - Define desired state for account resources
#   - Execute in targeted accounts based on OU path, tags, or names
#   - Run across multiple regions with region-aware context
#   - Maintain state files for drift detection
#   - Automatically remediate configuration drift on schedule
#   - Support cross-account orchestration for centralized services
#
# HOW IT WORKS:
# -------------
# 1. Terraform code stored in S3 defines desired account configuration
# 2. CodePipeline orchestrates deployment to targeted accounts
# 3. CodeBuild executes Terraform with injected account context variables
# 4. Terraform state stored in S3 tracks resource configuration
# 5. Scheduled execution ensures continuous compliance
# 6. Drift detection identifies and remediates unauthorized changes
#
# ARCHITECTURE:
# -------------
#   Terraform Code → S3 Bucket → CodePipeline → CodeBuild → Member Account(s)
#        (Git)          ↓             ↓            ↓            (Assume Role)
#                   Versioned     Orchestration  Execution
#                                      ↓            ↓
#                                 EventBridge   Terraform
#                                  (Schedule)    State (S3)
#
# WHY USE BASELINE TEMPLATES?
# ----------------------------
# ✓ Consistency: Standardized controls across all accounts
# ✓ Compliance: Continuous enforcement of security and governance
# ✓ Drift Detection: Automatically identify and fix unauthorized changes
# ✓ Scalability: Manage hundreds of accounts from single configuration
# ✓ Version Control: Track changes to governance policies over time
# ✓ Flexibility: Target specific accounts by OU, tags, or names
# ✓ Multi-Region: Deploy same configuration across multiple regions
# ✓ State Management: Terraform tracks resource lifecycle
# ✓ Cross-Account: Orchestrate resources in multiple accounts
# ✓ Auditability: Complete trail of what was deployed and when
#
# STANDARD TEMPLATES PROVIDED:
# -----------------------------
# 1. iam_role                   - Cross-account access roles, instance profiles
# 2. aws_config                 - AWS Config recorders, rules, compliance monitoring
# 3. openid_connect             - OIDC providers for CI/CD (GitHub, GitLab, Spacelift)
# 4. tfstate_backend            - Terraform state management infrastructure
#
# EXECUTION MODEL:
# ----------------
# Baselines execute via CodePipeline on:
#   • Initial deployment (when baseline is created)
#   • Scheduled intervals (e.g., every 24 hours for drift remediation)
#   • Manual triggers (on-demand execution)
#   • Code changes (when baseline templates are updated)
#
# REGIONAL DEPLOYMENT:
# --------------------
# The same baseline content executes in each configured region with:
#   • var.current_region: The region being deployed to
#   • var.main_region: The primary region for the account
#   • var.is_current_region_main_region: Boolean flag for region logic
#
# Global resources (IAM) should only be created in the main region:
#   resource "aws_iam_role" "example" {
#     count = var.is_current_region_main_region ? 1 : 0
#     # Only created in main region to avoid conflicts
#   }
#
# Regional resources get created in each region:
#   resource "aws_s3_bucket" "logs" {
#     bucket = "${var.current_account_id}-logs-${var.current_region}"
#     # Created in each region with region-specific naming
#   }
#
# INJECTED VARIABLES:
# -------------------
# Account Factory automatically provides these variables to all baseline templates:
#   • var.current_region: AWS region where baseline is deployed
#   • var.main_region: Primary region for the account
#   • var.partition: AWS partition (aws, aws-cn, aws-us-gov)
#   • var.is_current_region_main_region: Boolean for main region logic
#   • var.current_account_id: AWS account ID
#   • var.current_account_name: Account name
#   • var.current_account_email: Account email
#   • var.current_account_ou_path: Organizational unit path
#   • var.current_account_tags: Account tags (map)
#   • var.current_account_alternate_contacts: Alternate contacts (list)
#   • var.current_account_customer_values: Custom account values
#   • var.baseline_parameters: Scope-specific configuration parameters
#
# ACCOUNT TARGETING:
# ------------------
# Baselines can be precisely scoped to specific accounts using:
#   • OU paths: Apply to all accounts in specific organizational units
#   • Account names: Target specific accounts by name patterns
#   • Tags: Filter accounts by tag key-value pairs
#   • Exclusions: Explicitly exclude accounts from baseline
#
# Example scoping:
#   scope_include_accounts_by_ou_path = ["/root/production"]
#   scope_include_accounts_by_tags    = {Environment = "prod"}
#   scope_exclude_accounts_by_names   = ["prod-exception-account"]
#
# CROSS-ACCOUNT ORCHESTRATION:
# -----------------------------
# Baselines can assume roles in other accounts to configure centralized services:
#   • Transit Gateway attachments in connectivity account
#   • DNS subdomain delegations in Route53 account
#   • Security group rules in security account
#
# Example provider configuration:
#   baseline_assume_role_providers = [{
#     configuration_alias = "connectivity"
#     role_arn            = "arn:aws:iam::123456789012:role/ntc-account-baseline-role"
#     session_name        = "NTCBaselineRole"
#   }]
#
# BEST PRACTICES:
# ---------------
# ✓ Test baseline changes in non-production accounts first
# ✓ Use version control for all baseline templates
# ✓ Keep templates modular and reusable
# ✓ Document purpose and requirements of each template
# ✓ Use consistent naming conventions across accounts
# ✓ Leverage injected variables for dynamic configuration
# ✓ Deploy global resources only in main region
# ✓ Schedule regular baseline execution for drift remediation
# ✓ Monitor CodePipeline execution for failures
# ✓ Use baseline_parameters for environment-specific config
#
# DECOMMISSIONING:
# ----------------
# When removing baselines:
#   ⚠️  Set appropriate decommission flags to destroy resources
#   ⚠️  Consider impact on dependent resources
#   ⚠️  Backup state files before decommissioning
#   ⚠️  Decommission in non-production first to test
#
# DEPLOYMENT NOTES:
# -----------------
# ⚠️  Baseline applies to ALL accounts matching scope criteria
# ⚠️  Changes to baseline templates trigger automatic redeployment
# ⚠️  Terraform state is maintained per account per region for the account baseline
# ⚠️  Manual changes to baseline-managed resources will be reverted on next run
#
# =====================================================================================================================
module "account_baseline_templates" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-baseline-templates?ref=1.3.2"

  # -----------------------------------------------------------------------------------------------------------------
  # ACCOUNT BASELINE TEMPLATES
  # -----------------------------------------------------------------------------------------------------------------
  # Define Terraform-based configurations to maintain desired state across accounts
  # Templates execute via CodePipeline and maintain state for drift detection
  # Reference: https://docs.nuvibit.com/ntc-building-blocks/templates/ntc-account-baseline-templates/
  # -----------------------------------------------------------------------------------------------------------------
  account_baseline_templates = [
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 1: IAM Monitoring Reader Role
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Create cross-account IAM role for CloudWatch and monitoring access
    # 
    # WHAT IT DOES:
    #   - Creates an IAM role in each member account
    #   - Grants read-only access to CloudWatch, X-Ray, and monitoring services
    #   - Allows management/monitoring account to assume this role
    #   - Enables centralized monitoring without sharing credentials
    # 
    # USE CASES:
    #   ✓ Centralized CloudWatch dashboard across multiple accounts
    #   ✓ Cross-account log aggregation and analysis
    #   ✓ Unified observability platform for entire organization
    #   ✓ Security monitoring and alerting from dedicated account
    #   ✓ Cost optimization through centralized monitoring tools
    # 
    # TEMPLATE TYPE: iam_role
    #   The iam_role template creates IAM roles with configurable:
    #   - Trust policy (who can assume the role)
    #   - Permission policy (what the role can do)
    #   - Role attributes (name, path, session duration)
    #   - Instance profile (optional, for EC2)
    # 
    # CONFIGURATION:
    #   role_name: CloudWatch-CrossAccountSharingRole
    #     - Standard AWS role name for CloudWatch cross-account access
    #     - Used by AWS CloudWatch console for cross-account functionality
    #     - Must match role name expected by CloudWatch UI
    #   
    #   policy_json: Custom monitoring policy (defined below)
    #     - Read-only access to CloudWatch metrics, logs, dashboards
    #     - X-Ray trace analysis and service graph access
    #     - EC2 and ELB describe permissions for context
    #     - No write permissions (read-only monitoring)
    #   
    #   role_principal_type: AWS
    #     - Allows specific AWS accounts to assume this role
    #     - Used for cross-account access patterns
    #   
    #   role_principal_identifiers: [management_account_id]
    #     - List of AWS account IDs that can assume this role
    #     - Typically your organization management or monitoring account
    #     - Add multiple accounts if you have dedicated monitoring accounts
    # -----------------------------------------------------------------------------------------------------------------
    {
      file_name     = "iam_monitoring_reader"
      template_name = "iam_role"
      iam_role_inputs = {
        role_name  = "CloudWatch-CrossAccountSharingRole"
        policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
        # alternative: custom policy JSON for more granular control
        policy_json         = ""
        role_principal_type = "AWS"
        # grant permission to assume role in member account
        role_principal_identifiers = [
          local.account_factory_core_account_ids["aws-c2-management"] # replace with your monitoring account
        ]
      }
    },
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 2: IAM Instance Profile for EC2
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Create IAM instance profile for EC2 instances with Systems Manager access
    # 
    # WHAT IT DOES:
    #   - Creates an IAM role that EC2 instances can assume
    #   - Creates an instance profile (EC2-specific wrapper for IAM role)
    #   - Grants AWS Systems Manager (SSM) permissions
    #   - Enables Session Manager for secure shell access without SSH keys
    # 
    # USE CASES:
    #   ✓ Replace SSH key management with AWS SSM Session Manager
    #   ✓ Centralized EC2 instance management via Systems Manager
    #   ✓ Secure shell access without opening port 22 (SSH)
    #   ✓ Patch management through SSM Patch Manager
    #   ✓ Run commands across fleet of instances
    #   ✓ Inventory and configuration management
    # 
    # WHAT IS AN INSTANCE PROFILE?
    #   - AWS IAM construct that passes IAM role to EC2 instance
    #   - Required for EC2 instances to assume IAM roles
    #   - One-to-one relationship with IAM role
    #   - Attached to EC2 instance at launch or afterwards
    # 
    # TEMPLATE TYPE: iam_role with instance profile
    #   Same iam_role template as monitoring reader, but with:
    #   - role_is_instance_profile: true (creates instance profile)
    #   - role_principal_type: Service (allows EC2 service to assume)
    # 
    # CONFIGURATION:
    #   role_name: ntc-ssm-instance-profile
    #     - Used both as role name and instance profile name
    #     - Attach this to EC2 instances via launch template or console
    #   
    #   policy_arn: AmazonSSMManagedInstanceCore
    #     - AWS managed policy for Systems Manager core functionality
    #     - Enables Session Manager, Run Command, Patch Manager
    #     - No need to maintain custom policy for common use case
    #   
    #   role_principal_type: Service
    #     - Allows AWS services (not accounts) to assume role
    #     - Required for instance profiles
    #   
    #   role_principal_identifiers: ["ec2.amazonaws.com"]
    #     - Allows EC2 service to assume this role
    #     - Dynamically constructed using partition DNS suffix
    #     - Works across different AWS partitions (commercial, GovCloud, China)
    #   
    #   role_is_instance_profile: true
    #     - Creates instance profile in addition to IAM role
    #     - Makes role attachable to EC2 instances
    # 
    # DEPLOYMENT:
    #   - Created in main region only (IAM is global)
    #   - Deployed to all accounts matching baseline scope
    #   - Immediately available for EC2 instance attachment
    #   - Existing instances need restart to pick up profile
    # 
    # USAGE EXAMPLE:
    #   # In EC2 launch template or instance configuration:
    #   resource "aws_instance" "example" {
    #     instance_type        = "t3.micro"
    #     iam_instance_profile = "ntc-ssm-instance-profile"
    #     # EC2 instance can now use Systems Manager
    #   }
    # 
    # PREREQUISITES:
    #   - SSM agent installed on EC2 instances (default on Amazon Linux 2/2023)
    #   - Instances need outbound internet access or VPC endpoints for SSM
    #   - Systems Manager VPC endpoints if using private subnets
    # -----------------------------------------------------------------------------------------------------------------
    {
      file_name     = "iam_instance_profile"
      template_name = "iam_role"
      iam_role_inputs = {
        role_name           = "ntc-ssm-instance-profile"
        policy_arn          = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        role_principal_type = "Service"
        # grant permission to assume role in member account
        role_principal_identifiers = ["ec2.${local.current_partition_dns_suffix}"]
        # (optional) set to true to create an instance profile
        role_is_instance_profile = true
      }
    },
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 3: OIDC Provider for CI/CD Integration
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Configure OpenID Connect (OIDC) identity provider for passwordless CI/CD authentication
    # 
    # WHAT IT DOES:
    #   - Creates an IAM OIDC identity provider for your CI/CD platform
    #   - Creates an IAM role that CI/CD platform can assume without credentials
    #   - Configures trust policy with specific subject claims for security
    #   - Enables keyless authentication (no long-lived access keys)
    # 
    # USE CASES:
    #   ✓ Secure Terraform/OpenTofu deployments from CI/CD platforms
    #   ✓ Replace static AWS access keys with temporary credentials
    #   ✓ Scope access to specific CI/CD pipelines, repositories, or environments
    #   ✓ Audit CI/CD activity via CloudTrail (role assumption events)
    #   ✓ Automatically rotate credentials (no key management)
    # 
    # WHAT IS OIDC?
    #   OpenID Connect allows external identity providers (like Spacelift, GitHub Actions,
    #   GitLab CI, Terraform Cloud) to authenticate to AWS without storing long-lived credentials.
    #   
    #   How it works:
    #   1. CI/CD platform generates signed JWT token with claims (issuer, subject, audience)
    #   2. AWS validates token signature with OIDC provider's public keys
    #   3. AWS verifies token claims match role's trust policy conditions
    #   4. AWS issues temporary STS credentials (valid for max session duration)
    #   5. CI/CD uses temporary credentials to deploy infrastructure
    #   6. Credentials automatically expire after session duration
    # 
    # TEMPLATE TYPE: openid_connect
    #   Creates both OIDC provider and associated IAM role with:
    #   - Provider configuration (URL, audience, thumbprint)
    #   - Role trust policy (who can assume via OIDC)
    #   - Subject claim filters (which CI/CD jobs can assume)
    #   - Permission policy (what the role can do)
    # 
    # CONFIGURATION PARAMETERS:
    #   provider: <oidc-provider-url>
    #     - OIDC endpoint URL of your CI/CD platform
    #     - Examples: "nuvibit.app.spacelift.io", "token.actions.githubusercontent.com"
    #     - Must match the issuer claim in JWT tokens
    #   
    #   audience: <expected-audience>
    #     - Expected audience claim in OIDC token
    #     - Often matches provider URL for security
    #     - Some platforms use different audience values
    #   
    #   role_name: <iam-role-name>
    #     - IAM role name that CI/CD platform will assume
    #     - Use consistent naming across accounts for easier management
    #     - Example: "ntc-oidc-cicd-role" or "ntc-oidc-spacelift-role"
    #   
    #   role_max_session_in_hours: 1
    #     - Maximum duration for temporary credentials (1-12 hours)
    #     - 1 hour is typical for most Terraform/OpenTofu deployments
    #     - Increase if your deployments take longer
    #     - Shorter duration = better security, longer duration = more flexibility
    #   
    #   permission_policy_arn: <policy-arn>
    #     - AWS managed or customer managed policy ARN
    #     - Defines what the CI/CD role can do in the account
    #     - 'AdministratorAccess' is a typical policy for CI/CD pipelines
    #     - Least privilege is challenging for infrastructure pipelines (unpredictable resource needs)
    #     - Consider least privilege only if required by compliance (reduces pipeline flexibility)
    #   
    #   subject_list / subject_list_encoded: Claims filtering
    #     - CRITICAL SECURITY CONTROL: Limits which CI/CD jobs can assume role
    #     - Without proper subjects, ANY user on the CI/CD platform could access account
    #     - Use subject_list for simple static subjects
    #     - Use subject_list_encoded for dynamic/computed subjects
    #     - Supports Terraform expressions and injected variables
    # 
    # SUBJECT CLAIM STRUCTURE (Platform-Specific):
    #   
    #   Spacelift:
    #   Format: "space:SPACE_ID:stack:STACK_ID:run_type:RUN_TYPE:scope:RUN_PHASE"
    #   Examples:
    #     - "space:my-org-01ABC:stack:prod-app:*" → Only "prod-app" stack
    #     - "space:my-org-01ABC:stack:*:run_type:PROPOSED" → Any stack, plan only
    #   
    #   GitHub Actions:
    #   Format: "repo:ORG/REPO:environment:ENV" or "repo:ORG/REPO:ref:refs/heads/BRANCH"
    #   Examples:
    #     - "repo:myorg/myrepo:environment:production" → Production environment
    #     - "repo:myorg/myrepo:ref:refs/heads/main" → Main branch only
    #   
    #   GitLab CI:
    #   Format: "project_path:GROUP/PROJECT:ref_type:branch:ref:BRANCH"
    #   Examples:
    #     - "project_path:mygroup/myproject:ref_type:branch:ref:main"
    #     - "project_path:mygroup/*:ref_type:branch:ref:main" → All projects in group
    #   
    #   Terraform Cloud:
    #   Format: "organization:ORG:project:PROJECT:workspace:WORKSPACE:run_phase:PHASE"
    #   Examples:
    #     - "organization:myorg:project:prod:workspace:app:run_phase:apply"
    #     - "organization:myorg:project:*:workspace:*:run_phase:*" → All workspaces
    #   
    #   ⚠️  Wildcards (*) allow flexibility but reduce security - use sparingly!
    # 
    # ADVANCED: subject_list_encoded
    #   Uses Terraform expressions to dynamically generate subject list:
    #   - Reference injected variables: var.current_account_name, var.current_account_tags
    #   - Access account metadata: var.current_account_customer_values
    #   - Allows per-account customization without changing baseline code
    #   - Supports complex logic (flatten, for loops, conditionals)
    #   
    #   Example (Spacelift with dynamic subjects):
    #   ```hcl
    #   subject_list_encoded = <<EOT
    #   flatten([
    #     ["space:my-org:stack:$${var.current_account_name}:*"],
    #     [for stack in try(var.current_account_customer_values.additional_stacks, []) :
    #       "space:my-org:stack:$${stack}:*"
    #     ]
    #   ])
    #   EOT
    #   ```
    # 
    # EXAMPLE: Account Customer Values for Additional Subjects
    #   When creating account, provide custom values to grant access to multiple pipelines:
    #   ```json
    #   {
    #     "additional_oidc_subjects": [
    #       "shared-networking-stack",
    #       "security-baseline-stack"
    #     ]
    #   }
    #   ```
    #   Both the account's main stack AND these additional stacks can deploy.
    # 
    # SECURITY BEST PRACTICES:
    #   ⚠️  CRITICAL: Always use specific subject claims - never allow "*:*:*"
    #   ⚠️  Never use wildcard for all fields (allows any platform user to access account)
    #   ⚠️  Consider permission_boundary_arn for additional guardrails if required by compliance
    #   ⚠️  Rotate OIDC provider thumbprints if platform changes certificates
    #   ⚠️  Test with broad wildcards first, then narrow down for production
    # 
    # COMMON OIDC PROVIDER CONFIGURATIONS:
    #   
    #   Spacelift:
    #   provider: "<your-org>.app.spacelift.io"
    #   audience: "<your-org>.app.spacelift.io"
    #   subject: "space:SPACE_ID:stack:STACK_ID:*"
    #   
    #   GitHub Actions:
    #   provider: "token.actions.githubusercontent.com"
    #   audience: "sts.amazonaws.com"
    #   subject: "repo:ORG/REPO:environment:ENV"
    #   
    #   GitLab CI:
    #   provider: "gitlab.com"
    #   audience: "https://gitlab.com"
    #   subject: "project_path:GROUP/PROJECT:ref_type:branch:ref:main"
    #   
    #   Terraform Cloud:
    #   provider: "app.terraform.io"
    #   audience: "aws.workload.identity"
    #   subject: "organization:ORG:project:PROJ:workspace:WORKSPACE:run_phase:*"
    #   
    #   See inline comments below for complete subject format examples.
    # 
    # DEPLOYMENT:
    #   - Created in main region only (IAM is global)
    #   - Deployed to all accounts matching baseline scope
    #   - Immediately available for CI/CD authentication after creation
    #   - Update subject claims by modifying baseline and rerunning pipeline
    # 
    # TROUBLESHOOTING:
    #   If CI/CD platform can't assume role:
    #   ✓ Verify OIDC provider URL exactly matches JWT issuer claim
    #   ✓ Check subject claims match actual CI/CD job metadata
    #   ✓ Confirm role trust policy includes correct OIDC provider ARN
    #   ✓ Verify audience claim matches expected value
    #   ✓ Review CI/CD platform logs for specific error messages
    #   ✓ Check CloudTrail for failed AssumeRoleWithWebIdentity attempts
    #   ✓ Test with broader subject wildcard, then narrow down
    #   ✓ Validate OIDC thumbprint matches provider's certificate
    # 
    # BENEFITS OVER ACCESS KEYS:
    #   ✓ No long-lived credentials to rotate, manage, or accidentally leak
    #   ✓ Automatic credential expiration (max session duration)
    #   ✓ Granular control per CI/CD job, branch, or environment
    #   ✓ Easier to audit (role assumption events in CloudTrail)
    #   ✓ No credential storage in CI/CD platform configuration
    #   ✓ Supports just-in-time access (credentials only exist during job)
    #   ✓ Eliminates credential rotation burden
    # -----------------------------------------------------------------------------------------------------------------
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
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 4: AWS Config - Compliance and Configuration Monitoring
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Enable AWS Config for continuous compliance monitoring and resource tracking
    # 
    # WHAT IT DOES:
    #   - Creates AWS Config recorder in each enabled region
    #   - Records configuration changes for all supported resource types
    #   - Delivers configuration snapshots and change logs to S3
    #   - Enables baseline for compliance rules and conformance packs
    #   - Provides configuration history and relationship tracking
    # 
    # USE CASES:
    #   ✓ Track who changed what and when (configuration history)
    #   ✓ Enforce compliance rules (CIS benchmarks, PCI-DSS, HIPAA)
    #   ✓ Detect security misconfigurations automatically
    #   ✓ Audit resource relationships and dependencies
    #   ✓ Support incident investigation with configuration timeline
    #   ✓ Enable AWS Security Hub (requires Config)
    #   ✓ Demonstrate compliance for audits and certifications
    # 
    # WHAT IS AWS CONFIG?
    #   AWS Config continuously monitors and records AWS resource configurations.
    #   It provides:
    #   - Configuration history: See resource state at any point in time
    #   - Change tracking: Alerts when resources are modified
    #   - Compliance rules: Automated checks against best practices
    #   - Relationship mapping: Understand resource dependencies
    #   - Snapshot delivery: Regular configuration backups
    # 
    # TEMPLATE TYPE: aws_config
    #   Creates complete AWS Config setup:
    #   - Config recorder: Records resource configurations
    #   - Delivery channel: Sends config data to S3
    #   - IAM role: Grants Config permissions to read resources
    #   - Multi-region: Deploys recorder in each baseline region
    # 
    # CONFIGURATION:
    #   config_log_archive_bucket_arn: S3 bucket for config logs
    #     - Centralized bucket for all accounts' Config data
    #     - Typically in dedicated log archive account
    #     - Retrieved from 'ntc-parameters' (log-archive module outputs)
    #     - Enables organization-wide configuration analysis
    #   
    #   config_log_archive_kms_key_arn: KMS key for encryption
    #     - Encrypts Config data at rest in S3
    #     - Shared KMS key from log archive account
    #     - Config needs permission to use this key
    #   
    #   config_recorder_name: ntc-config-recorder
    #     - Name of Config recorder (one per region)
    #     - Consistent naming across accounts
    #   
    #   config_delivery_channel_name: ntc-config-delivery
    #     - Name of delivery channel to S3
    #     - Determines how often snapshots are sent
    #   
    #   config_iam_role_name: ntc-config-role
    #     - IAM role for Config service
    #     - Grants read access to all resource types
    #     - Grants write access to S3 bucket and KMS key
    #     - Must match with role name in 'ntc-log-archive' module input (var.config_iam_role_name)
    #   
    #   config_delivery_frequency: One_Hour
    #     - How often config snapshots are sent to S3
    #     - Options: One_Hour, Three_Hours, Six_Hours, Twelve_Hours, TwentyFour_Hours
    #     - More frequent = higher cost but faster compliance detection
    #   
    #   config_security_main_region: (optional)
    #     - Override main region for global resources (IAM, etc.)
    #     - Use when security tooling has different main region than accounts
    #     - This is necessary if Security Hub uses a different main region (e.g. SecurityHub eu-central-1, everything else eu-central-2)
    #     - Leave empty to use baseline's main_region
    # 
    # WHAT GETS RECORDED:
    #   AWS Config records ALL supported resource types by default:
    #   - EC2 instances, security groups, volumes, AMIs
    #   - VPCs, subnets, route tables, NACLs
    #   - IAM users, roles, policies, groups
    #   - S3 buckets and bucket policies
    #   - RDS databases, snapshots, parameter groups
    #   - Lambda functions, layers, aliases
    #   - And 200+ other resource types
    #   
    #   Global resources (IAM) recorded only in main region to avoid duplication
    # 
    # MULTI-REGION DEPLOYMENT:
    #   - Config recorder created in EACH baseline region
    #   - All regions send data to same central S3 bucket
    #   - Global resources (IAM) recorded only in main region
    #   - Regional resources recorded in their respective regions
    # 
    # INTEGRATION WITH SECURITY HUB:
    #   AWS Config is REQUIRED for Security Hub compliance checks:
    #   - Security Hub uses Config data for findings
    #   - Many Security Hub standards are Config rules
    #   - Must enable Config before enabling Security Hub
    # 
    # COST CONSIDERATIONS:
    #   AWS Config pricing (as of 2024):
    #   - Configuration items: $0.003 per item recorded
    #   - Typical account: 50-200 items per day = $5-60/month
    #   - Rules: Additional $0.001 per evaluation (added separately)
    #   - S3 storage: Adds to central log archive costs
    #   
    #   Cost optimization:
    #   ✓ Use longer delivery frequency (TwentyFour_Hours vs One_Hour)
    #   ✓ Exclude resource types you don't need (advanced)
    #   ✓ Enable lifecycle policies on S3 bucket to archive old data
    # 
    # SECURITY BENEFITS:
    #   ✓ Detect publicly accessible S3 buckets or databases
    #   ✓ Identify overly permissive security groups
    #   ✓ Track IAM policy changes and privilege escalations
    #   ✓ Monitor encryption status of resources
    #   ✓ Verify MFA enabled on root accounts
    #   ✓ Alert on unauthorized configuration changes
    # 
    # COMPLIANCE USE CASES:
    #   CIS AWS Foundations Benchmark:
    #   - Requires Config for many checks (password policy, MFA, etc.)
    #   
    #   PCI-DSS:
    #   - Config provides audit trail of changes
    #   - Proves security controls are maintained
    #   
    #   HIPAA:
    #   - Config tracks encryption and access control changes
    #   - Demonstrates continuous monitoring
    # 
    # PREREQUISITE:
    #   ⚠️  Log archive account must have Config bucket deployed
    #   ⚠️  Bucket policy must allow cross-account PutObject from all member accounts
    #   ⚠️  KMS key policy must allow Config service to encrypt data
    #   ⚠️  NTC Log Archive module handles these prerequisites automatically
    # 
    # BEST PRACTICES:
    #   ✓ Enable Config in ALL accounts and regions
    #   ✓ Use centralized S3 bucket for all Config data
    #   ✓ Enable encryption with KMS for sensitive data
    #   ✓ Add Config rules after recorder is established (separate step)
    #   ✓ Integrate with Security Hub for unified compliance view
    # 
    # NEXT STEPS AFTER CONFIG:
    #   1. Deploy AWS Config Rules for specific compliance checks
    #   2. Create Conformance Packs for compliance frameworks
    #   3. Enable AWS Security Hub with Config integration
    #   4. Set up aggregator for multi-account Config view
    #   5. Create dashboards for compliance metrics
    # -----------------------------------------------------------------------------------------------------------------
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
        config_security_main_region = ""
      }
    },
  ]
}