terraform {
  cloud {
    organization = "ananableu"
    
    workspaces {
      name = "zvr-lab"
    }
  }
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    aviatrix = {
      source  = "AviatrixSystems/aviatrix"
    #   version = "~>3.1"
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