# =====================================================================================================================
# NTC ACCOUNT LIFECYCLE TEMPLATES - EVENT-DRIVEN ACCOUNT AUTOMATION
# =====================================================================================================================
# Execute one-time actions automatically when accounts are created, updated, or closed
#
# PURPOSE OF LIFECYCLE ACTIONS:
# ------------------------------
# Account Lifecycle is designed for ONE-TIME, EVENT-DRIVEN operations that need to happen
# at specific moments in an account's lifecycle. These are "fire and forget" actions that:
#
#   ✓ Execute automatically when triggered by AWS Organizations events
#   ✓ Complete a specific task and finish (not ongoing management)
#   ✓ Are STATELESS - no state, no drift detection
#   ✓ Cannot be "updated" automatically - only executed once per trigger event
#   ✓ Ideal for setup tasks that shouldn't be reversed or managed long-term
#
# LIFECYCLE vs. BASELINE (Key Differences):
# ------------------------------------------
#   Account Lifecycle:                    | Account Baseline:
#   • Event-driven (reactive)             | • CI/CD-driven (proactive)
#   • One-time execution                  | • Continuous management
#   • Stateless                           | • Stateful (tracked in Terraform)
#   • Lambda-based automation             | • Terraform-based configuration
#   • Fast, targeted operations           | • Comprehensive governance
#   • "Set it and forget it"              | • Drift detection and remediation
#
# WHEN TO USE LIFECYCLE (vs. BASELINE):
# --------------------------------------
#   Use Lifecycle for:                    | Use Baseline for:
#   ✓ Enable opt-in regions               | ✓ Security baselines (GuardDuty, etc.)
#   ✓ Delete default VPCs                 | ✓ IAM policies and roles
#   ✓ Increase service quotas             | ✓ Networking baseline (VPC, Route53, etc.)
#   ✓ Tag shared resources                | ✓ Config rules
#   ✓ Move closed accounts to suspended   | ✓ Backup policies
#   ✓ Configure Enterprise Support        | ✓ Any configuration that needs updates
#   ✓ Create IAM account alias            | ✓ Resources requiring drift detection
#
# WHAT ARE LIFECYCLE TEMPLATES?
# ------------------------------
# Lifecycle templates are serverless workflows triggered by AWS Organizations events:
#   - CreateAccountResult: New account created → Run onboarding steps
#   - CloseAccountResult: Account closed → Run cleanup/suspension steps
#   - TagResource/UntagResource: Account tagged → Run tag-based actions (optional)
#
# HOW IT WORKS:
# -------------
# 1. AWS Organizations emits event to EventBridge when account lifecycle changes
# 2. EventBridge triggers Step Functions workflow
# 3. Step Functions executes Lambda functions in defined sequence
# 4. Each Lambda assumes 'OrganizationAccountAccessRole' in target account
# 5. Lambda performs one-time action (e.g., enable region, delete VPC)
# 6. Execution completes - no ongoing management
# 7. Results logged to CloudWatch
#
# ARCHITECTURE:
# -------------
#   AWS Organizations → EventBridge → Step Functions → Lambda → Member Account (One-time Action)
#      (Event)              ↓              ↓             ↓
#                      Filter Rules   State Machine   Execute
#                                         ↓              ↓
#                                    CloudWatch      Execution
#                                       Logs           Logs
#
#
# EXECUTION ORDER:
# ----------------
# Templates execute in the order defined in this list
# Consider dependencies when ordering:
#   ✓ Enable regions BEFORE other regional operations
#   ✓ Delete default VPC AFTER enabling opt-in regions
#   ✓ Move to suspended OU as LAST step for closed accounts
#
# ERROR HANDLING:
# ---------------
# • Each step has automatic retry logic
# • Failures trigger SNS notifications
# • Execution details logged to CloudWatch
# • Manual remediation possible via Step Functions console
#
# DEPLOYMENT NOTES:
# -----------------
# ⚠️  First deployment creates EventBridge rules and Step Functions
# ⚠️  Existing accounts are NOT affected by lifecycle templates
# ⚠️  Only NEW accounts (created after deployment) get automated setup
# ⚠️  To apply to existing accounts, manually trigger Step Functions or use 'account_lifecycle_customization_on_demand_triggers' in ntc-account-factory
#
# =====================================================================================================================
module "ntc_account_lifecycle_templates" {
  source = "github.com/nuvibit-terraform-collection/terraform-aws-ntc-account-lifecycle-templates?ref=2.0.0"

  # -----------------------------------------------------------------------------------------------------------------
  # ACCOUNT LIFECYCLE CUSTOMIZATION TEMPLATES
  # -----------------------------------------------------------------------------------------------------------------
  # Define automated steps to execute when accounts are created, updated, or closed
  # Templates are executed in the order defined below
  # Reference: https://docs.nuvibit.com/ntc-building-blocks/templates/ntc-account-lifecycle-templates/
  # -----------------------------------------------------------------------------------------------------------------
  account_lifecycle_customization_templates = [
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 1: Enable Opt-In Regions
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Automatically enable new AWS regions that require explicit opt-in
    # 
    # TRIGGER: CreateAccountResult (when new account is created)
    # 
    # WHAT IT DOES:
    #   - Enables specified opt-in regions in the new account
    #   - One-time action that cannot be easily reversed
    # 
    # AWS OPT-IN REGIONS:
    #   Regions requiring opt-in (as of 2024):
    #   - af-south-1 (Cape Town)
    #   - ap-east-1 (Hong Kong)
    #   - ap-south-2 (Hyderabad)
    #   - ap-southeast-3 (Jakarta)
    #   - ap-southeast-4 (Melbourne)
    #   - eu-central-2 (Zurich)
    #   - eu-south-1 (Milan)
    #   - eu-south-2 (Spain)
    #   - il-central-1 (Tel Aviv)
    #   - me-central-1 (UAE)
    #   - me-south-1 (Bahrain)
    # 
    # WHEN TO USE:
    #   ✓ Your organization needs to deploy resources in new AWS regions
    #   ✓ Data residency requirements mandate specific geographic locations
    #   ✓ You want to expand infrastructure to new regions automatically
    # 
    # IMPORTANT NOTES:
    #   ⚠️  Enabling regions takes 5-10 minutes to complete
    #   ⚠️  Ensure this runs BEFORE other regional operations
    #   ⚠️  SCP regional restrictions still apply even if region is enabled
    # 
    # EXECUTION ORDER: Should be FIRST in the sequence (other steps may need these regions)
    # -----------------------------------------------------------------------------------------------------------------
    {
      template_name               = "enable_opt_in_regions"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
      opt_in_regions              = ["eu-central-2"] # List all regions to enable
    },
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 2: Delete Default VPCs
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Remove default VPCs from all regions as a security best practice
    # 
    # TRIGGER: CreateAccountResult (when new account is created)
    # 
    # WHAT IT DOES:
    #   - Identifies default VPC in each enabled region
    #   - Deletes default subnets, internet gateways, and route tables
    #   - Removes the default VPC itself
    #   - Executed across ALL enabled regions (including opt-in regions)
    # 
    # SECURITY RATIONALE:
    #   ✓ Default VPCs have permissive security groups
    #   ✓ Default VPCs may have internet gateways you didn't request
    #   ✓ Prevents accidental deployment to unmanaged networks
    #   ✓ Forces deliberate network architecture decisions
    #   ✓ Aligns with CIS AWS Foundations Benchmark
    # 
    # WHAT GETS DELETED:
    #   - Default VPC (per region)
    #   - Default subnets (all AZs)
    #   - Default internet gateway
    #   - Default route tables
    #   - Default network ACLs
    #   - Default security group (if no dependencies)
    # 
    # IMPORTANT NOTES:
    #   ⚠️  Run AFTER enable_opt_in_regions to clean up all regions
    #   ⚠️  Requires no resources deployed in default VPC (fails if dependencies exist)
    #   ⚠️  Does NOT affect custom VPCs (only default VPCs)
    # 
    # ALTERNATIVE APPROACH:
    #   If you prefer to keep default VPCs but secure them, use account baseline
    #   templates to modify default security group rules instead
    # 
    # EXECUTION ORDER: Run AFTER enable_opt_in_regions, BEFORE resource deployment
    # -----------------------------------------------------------------------------------------------------------------
    {
      template_name               = "delete_default_vpc"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
    },
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 3: Increase Service Quotas
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Preemptively raise service limits to prevent deployment failures
    # 
    # TRIGGER: CreateAccountResult (when new account is created)
    # 
    # WHAT IT DOES:
    #   - Requests service quota increases for specified services
    #   - Applies increases to specified regions
    #   - Processes quota requests automatically (if within AWS auto-approval limits)
    #   - Prevents hitting default service limits during initial deployments
    # 
    # COMMON QUOTAS TO INCREASE:
    #   Regional Quotas:
    #   - EC2: Running On-Demand instances (default: varies by instance type)
    #   - VPC: VPCs per region (default: 5)
    #   - ELB: Application Load Balancers (default: 50)
    #   - ELB: Network Load Balancers (default: 50)
    #   - Lambda: Concurrent executions (default: 1000)
    #   - RDS: DB instances (default: 40)
    # 
    #   Global Quotas (apply in us-east-1 for AWS commercial partition):
    #   - IAM: Managed policies per role (default: 10)
    #   - IAM: Roles per account (default: 5000)
    #   - IAM: Policies per account (default: 1500)
    #   - Route53: Hosted zones (default: 500)
    # 
    # WHEN TO USE:
    #   ✓ Your default deployments regularly hit service limits
    #   ✓ You want to prevent quota-related failures in new accounts
    #   ✓ Baseline deployments require higher limits than defaults
    #   ✓ You create many accounts and want consistent quotas
    # 
    # WHEN NOT TO USE:
    #   ✗ Default quotas are sufficient for your use case
    #   ✗ You prefer to request increases on-demand
    #   ✗ Quotas require AWS support ticket approval (use Organizations quota templates instead)
    # 
    # IMPORTANT NOTES:
    #   ⚠️  Global IAM quotas MUST be requested in us-east-1 region (AWS commercial partition)
    #   ⚠️  Some quota increases require AWS support approval (not instant)
    #   ⚠️  This is ONE-TIME - you need to manage future increases separately
    #   ⚠️  Quota increases may have cost implications (higher limits enable more resources)
    #   ⚠️  Check AWS service quota documentation for auto-approval limits
    # 
    # FINDING SERVICE CODES AND QUOTA NAMES:
    #   AWS CLI: aws service-quotas list-service-quotas --service-code <code>
    #   Common service codes: ec2, vpc, elasticloadbalancing, lambda, rds, iam, s3
    # 
    # ALTERNATIVE: Organizations Service Quota Templates
    #   For ongoing quota management across all new accounts, use Organizations
    #   service quota templates (configured in ntc-organizations module) instead
    # -----------------------------------------------------------------------------------------------------------------
    {
      template_name               = "increase_service_quota"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
      quota_increases = [
        {
          # Global IAM quotas MUST be in us-east-1 for AWS commercial partition
          region       = "us-east-1"
          quota_name   = "Managed policies per role" # Exact quota name from AWS Service Quotas
          service_code = "iam"                       # Service code identifier
          value        = 20                          # New quota value (must be >= current value)
        }
        # Add more quota increases as needed:
        # {
        #   region       = "eu-central-1"
        #   quota_name   = "Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances"
        #   service_code = "ec2"
        #   value        = 100
        # }
      ]
    },
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 4: Tag Shared Resources
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Automatically tag resources shared via AWS Resource Access Manager (RAM)
    # 
    # TRIGGER: CreateAccountResult (when new account is created)
    # 
    # WHAT IT DOES:
    #   - Discovers resources shared with the account via AWS RAM
    #   - Applies tags from the resource owner account to shared resources (tags don't get shared)
    #   - Works across specified regions where resources might be shared
    # 
    # COMMONLY SHARED RESOURCES VIA RAM:
    #   - VPC subnets (from network/connectivity account)
    #   - Transit Gateway attachments
    #   - Route53 Resolver rules
    #   - AWS Network Firewall policies
    #   - VPC Prefix Lists
    # 
    # WHEN TO USE:
    #   ✓ Your organization uses centralized networking (shared VPC subnets)
    #   ✓ Compliance tracking needs to identify resource ownership
    #   ✓ You want visibility into RAM-shared resources
    # 
    # WHEN NOT TO USE:
    #   ✗ You don't use AWS Resource Access Manager
    #   ✗ Shared resources are already tagged by the sharing account
    #   ✗ Your tagging strategy doesn't require shared resource identification
    # 
    # BENEFITS:
    #   ✓ Improved resource discovery and inventory
    #   ✓ Easier troubleshooting (know what you can/can't modify)
    #   ✓ Enhanced security posture (identify external dependencies)
    # 
    # IMPORTANT NOTES:
    #   ⚠️  Only tags resources in specified regions (shared_resources_regions)
    #   ⚠️  Some resource types may not support tagging via RAM
    #   ⚠️  Tagging shared resources doesn't grant modification permissions
    # 
    # CONFIGURATION:
    #   shared_resources_regions: List of regions where you expect shared resources
    #   - Include all regions where your network/connectivity account shares resources
    #   - Match regions used in your organization's network architecture
    # -----------------------------------------------------------------------------------------------------------------
    {
      template_name               = "tag_shared_resources"
      organizations_event_trigger = "CreateAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
      shared_resources_regions    = ["eu-central-1", "eu-central-2"] # Regions to scan for shared resources
    },
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 5: Move to Suspended OU
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Automatically quarantine closed accounts by moving them to suspended OU
    # 
    # TRIGGER: CloseAccountResult (when account is closed via AWS Organizations)
    # 
    # WHAT IT DOES:
    #   - Detects when an account is closed
    #   - Moves the closed account to a dedicated suspended OU
    #   - Inherits restrictive SCPs from suspended OU (blocks all actions)
    #   - Prevents any activity in the closed account
    # 
    # AWS ACCOUNT CLOSURE PROCESS:
    #   When an account is closed:
    #   1. Account enters 90-day grace period (can be reopened)
    #   2. CloseAccountResult event triggers
    #   3. This template moves account to suspended OU
    #   4. SCPs block all actions except organization admin
    #   5. After 90 days, account is permanently closed
    # 
    # SUSPENDED OU CHARACTERISTICS:
    #   - Should have deny-all SCP attached (guardrails are applied via 'ntc-organizations')
    #   - Prevents resource creation/modification
    #   - Blocks all IAM principal access (except OrganizationAccountAccessRole)
    #   - Allows organization management to access for cleanup
    # 
    # WHEN TO USE:
    #   ✓ You close accounts regularly (development, testing, projects ending)
    #   ✓ Need to prevent activity in closed accounts during grace period
    # 
    # WHEN NOT TO USE:
    #   ✗ You never close accounts
    #   ✗ Closed accounts should remain in original OU
    #   ✗ You have custom closure workflows
    # 
    # SECURITY BENEFITS:
    #   ✓ Prevents unauthorized access to closed account resources
    #   ✓ Blocks potential security incidents in abandoned accounts
    #   ✓ Enforces consistent handling of account closure
    # 
    # IMPORTANT NOTES:
    #   ⚠️  Requires /root/suspended OU to exist (created in 'ntc-organizations')
    #   ⚠️  Suspended OU should have deny-all SCP attached
    # -----------------------------------------------------------------------------------------------------------------
    {
      template_name               = "move_to_suspended_ou"
      organizations_event_trigger = "CloseAccountResult"
      organizations_member_role   = "OrganizationAccountAccessRole"
      # Dynamically retrieve suspended OU ID from NTC parameters
      # Falls back to empty string if OU doesn't exist (template will skip execution)
      suspended_ou_id = local.ntc_parameters["mgmt-organizations"]["ou_ids"]["/root/suspended"]
    },
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 6: Enable Enterprise Support
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Automatically configure AWS Enterprise Support for new accounts
    # 
    # TRIGGER: CreateAccountResult (when new account is created)
    # 
    # WHAT IT DOES:
    #   - Enables AWS Enterprise Support in the new account via support case
    #   - Configures support case notification recipients
    #   - Sets company name for support case context
    #   - Links account to organization's Enterprise Support plan
    # 
    # AWS ENTERPRISE SUPPORT BENEFITS:
    #   - 24/7 phone, email, and chat access to Cloud Support Engineers
    #   - 15-minute response time for business-critical issues
    #   - Technical Account Manager (TAM) assigned
    #   - Infrastructure Event Management
    #   - Well-Architected Reviews
    #   - Operations Reviews
    #   - Training and workshops
    # 
    # SUPPORT PLAN LEVELS:
    #   - Basic: Free (AWS documentation and forums)
    #   - Developer: $29/month (business hours email support)
    #   - Business: Starting $100/month (24/7 support, < 1 hour response)
    #   - Enterprise On-Ramp: Starting $5,500/month (TAM pool, < 30 min response)
    #   - Enterprise: Starting $15,000/month (dedicated TAM, < 15 min response)
    # 
    # PREREQUISITES:
    #   ⚠️  Organization MUST have Enterprise Support plan active
    #   ⚠️  Cannot enable Enterprise Support in individual accounts without org plan
    #   ⚠️  All accounts in organization inherit the support plan
    # 
    # WHEN TO USE:
    #   ✓ Your organization has AWS Enterprise Support
    #   ✓ Want consistent support case routing across accounts
    #   ✓ Require immediate support configuration for production accounts
    # 
    # WHEN NOT TO USE:
    #   ✗ Organization doesn't have Enterprise Support
    #   ✗ Using Business or lower support tiers
    #   ✗ Support configuration is handled separately
    # 
    # CONFIGURATION PARAMETERS:
    #   company_name:
    #     - Displayed in AWS Support Center
    #     - Helps AWS support engineers provide context-aware assistance
    #     - Should match your official company name
    #   
    #   cc_email_addresses:
    #     - Recipients for support case notifications
    #     - Can include distribution lists for team notifications
    #     - Recommended: Use team aliases, not individual addresses
    #     - Support cases will CC these addresses on updates
    # 
    # COST CONSIDERATIONS:
    #   - Enterprise Support costs are at organization level, not per account
    #   - Adding accounts doesn't increase base support fees
    #   - Support costs scale with monthly AWS usage
    #   - Reference: https://aws.amazon.com/premiumsupport/plans/
    # -----------------------------------------------------------------------------------------------------------------
    {
      template_name               = "enable_enterprise_support"
      organizations_event_trigger = "CreateAccountResult"
      company_name                = "Nuvibit" # Your organization's official name
      cc_email_addresses = [                  # Support notification recipients
        "accounts+test1@nuvibit.com",
        "accounts+test2@nuvibit.com"
      ]
    },
    # -----------------------------------------------------------------------------------------------------------------
    # TEMPLATE 7: Create Account Alias
    # -----------------------------------------------------------------------------------------------------------------
    # PURPOSE: Set human-readable IAM account alias for easier identification and sign-in
    # 
    # TRIGGER: CreateAccountResult (when new account is created)
    # 
    # WHAT IT DOES:
    #   - Reads account alias from specified account tag
    #   - Creates IAM account alias using the tag value
    #   - Enables friendly sign-in URL: https://<alias>.signin.aws.amazon.com/console
    #   - Displays alias in AWS Console (top-right corner)
    # 
    # IAM ACCOUNT ALIAS BENEFITS:
    #   ✓ Human-readable sign-in URLs (use alias instead of account ID)
    #   ✓ Easier to identify which account you're working in
    #   ✓ Improved user experience for teams accessing multiple accounts
    # 
    # HOW IT WORKS:
    #   1. Account is created with a tag (e.g., AccountAlias: "prod-app-1")
    #   2. This template reads the AccountAlias tag value
    #   3. Creates IAM account alias using that value
    #   4. Sign-in URL becomes: https://prod-app-1.signin.aws.amazon.com/console
    #   5. AWS Console shows "prod-app-1" instead of account ID
    # 
    # ACCOUNT ALIAS REQUIREMENTS:
    #   - Must be globally unique across ALL AWS accounts
    #   - 3-63 characters long
    #   - Lowercase letters, numbers, and hyphens only
    #   - Must start and end with letter or number
    #   - Cannot contain consecutive hyphens
    #   - One alias per account (previous alias is replaced if changed)
    # 
    # WHEN TO USE:
    #   ✓ Need human-readable account identification
    #   ✓ Want consistent account naming visible in console
    #   ✓ Multiple accounts with similar purposes need differentiation
    #   ✓ Improving user experience for console access
    # 
    # WHEN NOT TO USE:
    #   ✗ Account alias not needed for your workflow
    #   ✗ Concerned about global namespace conflicts
    # 
    # CONFIGURATION:
    #   account_alias_tag_key:
    #     - Name of the account tag containing desired alias
    #     - Default: "AccountAlias"
    #     - Tag must be present on account at creation time
    #     - Template fails gracefully if tag is missing
    # 
    # EXAMPLE ACCOUNT TAG:
    #   When creating account in account factory, include:
    #   account_tags = {
    #     AccountAlias = "prod-app-1"
    #     Environment  = "Production"
    #     CostCenter   = "Engineering"
    #   }
    # 
    # NAMING CONVENTIONS:
    #   Recommended patterns:
    #   - <company>-<app>-<env>: aws-webapp-prod, aws-api-dev
    #   - <department>-<app>-<env>: finance-api-prod, distribution-api-dev
    # 
    # IMPORTANT NOTES:
    #   ⚠️  Account alias is GLOBALLY UNIQUE across all AWS accounts
    #   ⚠️  If alias exists, template will fail (must choose different alias)
    #   ⚠️  Alias can be changed later, but only one alias per account
    #   ⚠️  Deleting alias requires manual action
    #   ⚠️  Consider your naming strategy carefully to avoid conflicts
    # 
    # ALTERNATIVE: AWS IAM Identity Center
    #   If using SSO, consider whether account aliases are needed
    #   - SSO provides named access portals
    #   - Account alias mainly benefits IAM user sign-in
    #   - Both can coexist if you use mixed authentication
    # -----------------------------------------------------------------------------------------------------------------
    {
      template_name               = "create_account_alias"
      organizations_event_trigger = "CreateAccountResult"
      account_alias_tag_key       = "AccountAlias" # Tag key containing desired account alias
    },
  ]
}