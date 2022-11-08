resource "azurerm_linux_virtual_machine" "this" {
  name                = "${var.gameserver_name}-${var.env}-vm"
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  size                = "Standard_D4s_v4"
  admin_username      = random_string.username.result
  network_interface_ids = [
    azurerm_network_interface.this.id
  ]

  admin_ssh_key {
    username   = random_string.username.result
    public_key = tls_private_key.this.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "this" {
  virtual_machine_id = azurerm_linux_virtual_machine.this.id
  location           = local.resource_group_location
  enabled            = true

  daily_recurrence_time = "0000"
  timezone              = "GMT Standard Time"

  notification_settings {
    enabled = false
  }
}
