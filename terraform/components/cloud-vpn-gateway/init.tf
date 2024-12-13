terraform {
  required_version = "1.10.2"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.13.0"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}
