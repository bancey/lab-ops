terraform {
  required_version = "1.10.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.14.0"
    }
    github = {
      source  = "integrations/github"
      version = "6.4"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

provider "github" {
  owner = "bancey"
  app_auth {
    id              = data.azurerm_key_vault_secret.github_app_id.value
    installation_id = data.azurerm_key_vault_secret.github_installation_id.value
    pem_file        = file("../../../private-key.pem")
  }
}
