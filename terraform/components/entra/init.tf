terraform {
  required_version = "1.16.1"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.10.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.14.2"
    }
    github = {
      source  = "integrations/github"
      version = "6.13"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
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

# Commits the rendered SOPS secrets as the same GitHub App that terraform/components/inventory
# uses, which is the identity this repository already uses for machine-generated commits.
provider "github" {
  owner = "bancey"
  app_auth {
    id              = data.azurerm_key_vault_secret.github_app_id.value
    installation_id = data.azurerm_key_vault_secret.github_installation_id.value
    pem_file        = file("../../../private-key.pem")
  }
}
