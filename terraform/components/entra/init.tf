terraform {
  required_version = "1.16.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.10.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.14.2"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

# The azuread provider picks up ARM_CLIENT_ID / ARM_CLIENT_SECRET / ARM_TENANT_ID from the
# environment, the same credentials the azurerm backend uses. tenant_id is set explicitly so a
# local run against the wrong default tenant fails fast instead of creating objects elsewhere.
provider "azuread" {
  tenant_id = var.tenant_id
}
