terraform {
  required_version = "1.14.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.62.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "random" {}
