module "dns_record" {
  source = "../../modules/dns-record"
  count  = var.gameserver_count

  subdomain   = "${var.gameserver_name}${count.index + 1}"
  record_type = "A"
  ttl         = "60"
  ip_address  = module.pterodactyl_node[count.index].public_ip
}
