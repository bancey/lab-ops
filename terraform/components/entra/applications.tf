resource "azuread_application" "this" {
  for_each = local.applications

  display_name            = each.value.display_name
  description             = lookup(each.value, "description", null)
  sign_in_audience        = lookup(each.value, "sign_in_audience", "AzureADMyOrg")
  group_membership_claims = lookup(each.value, "group_membership_claims", ["SecurityGroup"])
  prevent_duplicate_names = true
  owners                  = [data.azuread_client_config.current.object_id]

  # An app with an exposed API needs an identifier URI built from its own client ID, which can't
  # be set here without a cycle, so azuread_application_identifier_uri.this owns it.
  lifecycle {
    ignore_changes = [identifier_uris]
  }

  # Only for apps that expose an API scope, e.g. lab-openziti-admin, whose access tokens are the
  # credential. requested_access_token_version is pinned rather than left to the default, because
  # the token version decides the issuer (v1: https://sts.windows.net/<tenant>/) and downstream
  # verifiers match the issuer exactly. See docs/openziti.md.
  dynamic "api" {
    for_each = contains(keys(each.value), "api") ? [each.value.api] : []
    content {
      requested_access_token_version = lookup(api.value, "requested_access_token_version", 2)

      dynamic "oauth2_permission_scope" {
        for_each = lookup(api.value, "scopes", {})
        content {
          # Deterministic, so the scope keeps its ID across plans without extra state
          id                         = uuidv5("url", "api://${each.key}/${oauth2_permission_scope.key}")
          value                      = oauth2_permission_scope.key
          type                       = "User"
          enabled                    = true
          admin_consent_display_name = oauth2_permission_scope.value
          admin_consent_description  = oauth2_permission_scope.value
          user_consent_display_name  = oauth2_permission_scope.value
          user_consent_description   = oauth2_permission_scope.value
        }
      }
    }
  }

  web {
    redirect_uris = lookup(each.value, "redirect_uris", [])

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = lookup(each.value, "id_token_issuance_enabled", false)
    }
  }

  # Only emitted for apps that need a native/CLI flow, e.g. kubelogin on http://localhost:8000.
  dynamic "public_client" {
    for_each = length(lookup(each.value, "public_client_redirect_uris", [])) > 0 ? [1] : []
    content {
      redirect_uris = each.value.public_client_redirect_uris
    }
  }

  dynamic "single_page_application" {
    for_each = length(lookup(each.value, "spa_redirect_uris", [])) > 0 ? [1] : []
    content {
      redirect_uris = each.value.spa_redirect_uris
    }
  }

  optional_claims {
    dynamic "id_token" {
      for_each = toset(lookup(each.value, "optional_claims", local.default_optional_claims))
      content {
        name = id_token.value
      }
    }

    dynamic "access_token" {
      for_each = toset(lookup(each.value, "optional_claims", local.default_optional_claims))
      content {
        name = access_token.value
      }
    }
  }

  required_resource_access {
    resource_app_id = local.graph_app_id

    dynamic "resource_access" {
      for_each = toset(lookup(each.value, "graph_scopes", local.default_graph_scopes))
      content {
        id   = local.graph_delegated_scope_ids[resource_access.value]
        type = "Scope"
      }
    }
  }
}

resource "azuread_application_identifier_uri" "this" {
  for_each       = { for name, app in local.applications : name => app if contains(keys(app), "api") }
  application_id = azuread_application.this[each.key].id
  identifier_uri = "api://${azuread_application.this[each.key].client_id}"
}

resource "azuread_service_principal" "this" {
  for_each  = local.applications
  client_id = azuread_application.this[each.key].client_id
  owners    = [data.azuread_client_config.current.object_id]

  # Entra ID Free cannot assign *groups* to an enterprise application, so requiring assignment
  # would mean maintaining a per-user list in two places. Authorization is enforced downstream
  # from the groups claim instead — see docs/sso-operations.md. The exception is an app whose
  # tokens grant administrative access (assignment_required: true), where the per-user list is
  # worth it. Users are assigned by hand: doing it here would need AppRoleAssignment.ReadWrite.All,
  # which lets the pipeline grant itself any permission.
  app_role_assignment_required = lookup(each.value, "assignment_required", false)

  feature_tags {
    enterprise = true
  }
}
