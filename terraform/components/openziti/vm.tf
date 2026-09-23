module "openziti_vm" {
  providers = {
    proxmox = proxmox.wanda
  }

  source = "../../modules/proxmox-vm"

  target_node         = var.openziti.node
  vm_name             = "openziti"
  vm_id               = var.openziti.vm_id
  vm_description      = var.openziti.vm_description
  cpu_cores           = var.openziti.cpu_cores
  memory              = var.openziti.memory
  ip_address          = "${var.openziti.ip_address}/24"
  gateway_ip_address  = var.openziti.gateway_ip_address
  network_bridge_name = var.openziti.network_bridge_name
  vlan_tag            = try(var.openziti.vlan_tag, null)
  startup_order       = var.openziti.startup_order
  startup_delay       = var.openziti.startup_delay
  storage             = var.openziti.storage
  disk_size           = var.openziti.disk_size
  username            = data.azurerm_key_vault_secret.lab_vm_username.value
  password            = data.azurerm_key_vault_secret.lab_vm_password.value
  image_id            = "local:iso/${var.openziti.image}"
  tags                = ["openziti", "phase1"]
}

resource "terraform_data" "openziti_ansible" {
  depends_on = [module.openziti_vm]

  triggers_replace = {
    ansible_trigger = var.openziti.ansible_trigger
    vm_module       = jsonencode(module.openziti_vm)
    playbook_md5    = filemd5("../../../ansible/openziti.yaml")
  }

  provisioner "local-exec" {
    command = templatefile("${path.module}/ansible.sh.tpl", {
      ip_address         = var.openziti.ip_address
      ansible_user       = data.azurerm_key_vault_secret.lab_vm_username.value
      controller_address = var.openziti.controller_address
      test_identity_name = var.openziti.test_identity_name
      test_service_name  = var.openziti.test_service_name
      test_service_host  = var.openziti.test_service_host
      test_service_port  = var.openziti.test_service_port
    })
    environment = {
      OPENZITI_ADMIN_USERNAME = data.azurerm_key_vault_secret.openziti_admin_username.value
      OPENZITI_ADMIN_PASSWORD = data.azurerm_key_vault_secret.openziti_admin_password.value
    }
    working_dir = replace(path.cwd, "/terraform/components/openziti", "/ansible")
    interpreter = ["/bin/bash", "-c"]
  }
}
