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