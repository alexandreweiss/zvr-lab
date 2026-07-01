variable "aviatrix_controller_ip" {
  description = "Aviatrix Controller FQDN or IP (e.g. controller.example.com)"
  type        = string
}

variable "aviatrix_username" {
  description = "Aviatrix Controller admin username"
  type        = string
  default     = "admin"
}

variable "aviatrix_password" {
  description = "Aviatrix Controller admin password"
  type        = string
  sensitive   = true
}

variable "aviatrix_azure_account_name" {
  description = "Name of the Aviatrix Azure account"
  type        = string
}

variable "block_ipify" {
  description = "Block api.ipify.org from all spokes via FQDN webgroup"
  type        = bool
  default     = false
}

variable "dcf_scenario" {
  description = "DCF enforcement scenario: 'allow_all' (baseline), 'deny_icmp' (block ping only), 'deny_all' (full block)"
  type        = string
  default     = "allow_all"

  validation {
    condition     = contains(["allow_all", "deny_icmp", "deny_all"], var.dcf_scenario)
    error_message = "dcf_scenario must be one of: allow_all, deny_icmp, deny_all."
  }
}
