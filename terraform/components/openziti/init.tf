terraform {
  required_version = "1.16.4"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.7.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.10.0"
    }
    ziti = {
      source  = "netfoundry/ziti"
      version = "2.1.3"
    }
  }

  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

# Same credentials the azurerm backend uses, as in the entra component. Only used to resolve the
# lab-* group names to the object IDs that the Entra groups claim carries.
provider "azuread" {
  tenant_id = var.tenant_id
}

# The management API shares the public controller port, so the pipeline needs neither Twingate nor
# the OVH SSH rule. The certificate comes from the controller's own PKI, which no OS trusts, hence
# the CA. It is public material, but kept in Key Vault so the component has no per-host input.
provider "ziti" {
  host     = local.openziti.controller_url
  username = data.azurerm_key_vault_secret.admin_username.value
  password = data.azurerm_key_vault_secret.admin_password.value
  ca       = data.azurerm_key_vault_secret.controller_ca.value
}
