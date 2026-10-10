terraform {
  required_version = "1.16.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.8.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.10.0"
    }
    ziti = {
      source  = "netfoundry/ziti"
      version = "2.2.0"
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
# the CA. The provider appends /authenticate and /configs to host as is, so host has to be the
# management API root, not just the controller address. The CA is public material, but kept in Key Vault so the component has no per-host input.
provider "ziti" {
  host     = "${trimsuffix(local.openziti.controller_url, "/")}/edge/management/v1"
  username = data.azurerm_key_vault_secret.admin_username.value
  password = data.azurerm_key_vault_secret.admin_password.value
  ca       = data.azurerm_key_vault_secret.controller_ca.value
}
