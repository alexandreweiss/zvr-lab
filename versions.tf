terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
      version = "~>9.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~>4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~>2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "aviatrix" {
  controller_ip = var.aviatrix_controller_ip
  username      = var.aviatrix_username
  password      = var.aviatrix_password
}
