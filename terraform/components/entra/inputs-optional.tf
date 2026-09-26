variable "entra_yaml_path" {
  type        = string
  description = "The path to the yaml file containing the Entra ID group and app registration config."
  default     = null
}

variable "grant_admin_consent" {
  type        = bool
  description = <<-EOT
    Grant tenant-wide admin consent for each application's delegated Microsoft Graph scopes.
    Requires the deploying service principal to hold DelegatedPermissionGrant.ReadWrite.All (or
    Application.ReadWrite.All), which Application.ReadWrite.OwnedBy does not include. Leave false
    and consent once per user at first sign-in, or click "Grant admin consent" in the portal.
  EOT
  default     = false
}
