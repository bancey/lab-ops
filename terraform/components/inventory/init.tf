terraform {
  required_version = "1.9.5"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "2.5.1"
    }
  }

  backend "azurerm" {}
}

provider "local" {}
