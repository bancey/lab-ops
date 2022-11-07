locals {
  tags = merge(
    var.tags,
    {
      "application" = "gameserver",
      "environment" = var.env,
    }
  )
}
