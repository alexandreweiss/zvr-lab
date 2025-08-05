variable "aviatrix_controller_ip" {
  description = "Aviatrix Controller IP address"
  type        = string
}

variable "aviatrix_username" {
  description = "Aviatrix Controller username"
  type        = string
}

variable "aviatrix_password" {
  description = "Aviatrix Controller password"
  type        = string
  sensitive   = true
}

variable "aviatrix_azure_account_name" {
  description = "Name of the Aviatrix Azure account"
  type        = string
  default     = "azure-alweiss"
}
