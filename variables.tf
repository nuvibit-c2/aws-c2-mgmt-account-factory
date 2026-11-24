# injected by spacelift in every run as 'TF_VAR_spacelift_space_id'
# https://docs.spacelift.io/concepts/configuration/environment#computed-values
variable "spacelift_space_id" {
  description = "Spacelift space id of the current stack (e.g. 'aws-c2-01HMSG08P7X6MD11FYV831WN2B'). Used for the spacelift oidc subjects in the account baseline."
  type        = string
}

# credentials should be referenced from a secrets manager (aws secrets manager, hashicorp vault) or like in this case from environment variables starting with 'TF_VAR_'
variable "account_baseline_git_ssh_key" {
  description = "private key used in account baseline to copy modules with ssh"
  type        = string
  default     = "placeholder"
  sensitive   = true
}

variable "account_baseline_github_access_token" {
  description = "token used in account baseline to copy modules from github with https"
  type        = string
  default     = "placeholder"
  sensitive   = true
}

variable "account_baseline_terraform_registry_token" {
  description = "token used in account baseline to copy modules from terraform registry"
  type        = string
  default     = "placeholder"
  sensitive   = true
}
