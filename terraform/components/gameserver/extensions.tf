resource "null_resource" "update-script" {
  count = var.gameserver_count
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
                  cp bootstrap.sh bootstrap${count.index + 1}.sh
                  sed -i "s/subdomain/${var.gameserver_name}${count.index + 1}-${var.env}" bootstrap${count.index + 1}.sh
    EOT
  }
}

resource "azurerm_virtual_machine_extension" "customscript" {
  depends_on = [
    null_resource.update-script
  ]
  count                      = var.gameserver_count
  name                       = "BootstrapVM"
  virtual_machine_id         = azurerm_linux_virtual_machine.this[count.index].id
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = 2.1
  auto_upgrade_minor_version = false
  protected_settings         = <<PROTECTED_SETTINGS
  {
    "script": "${base64encode(file("${path.module}/bootstrap${count.index + 1}.sh"))}"
  }
  PROTECTED_SETTINGS
}
