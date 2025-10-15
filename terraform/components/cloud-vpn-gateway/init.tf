terraform {
  required_version = "1.13.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.48.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "random" {}
