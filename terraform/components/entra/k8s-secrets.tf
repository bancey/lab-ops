# Renders the SOPS-encrypted Kubernetes Secrets for the app registrations above and commits them.
#
# This lives in the same component as the app registrations on purpose. Terraform already knows
# the client secret value and knows precisely when it has been replaced, so a file is re-rendered
# only when one of its inputs actually changes. A separate component would have had to infer that
# by decrypting the committed file and diffing it, which needs the age private key on the agent
# and is fragile because sops is non-deterministic.
#
# Ordering within one apply: random_bytes / azuread_application_password -> terraform_data
# (renders the file) -> data.local_file (reads it back) -> github_repository_file (commits it).

resource "random_bytes" "shared" {
  for_each = local.shared_random_secrets
  length   = lookup(each.value, "length", 32)
}

resource "terraform_data" "sops_secret" {
  for_each = local.k8s_secrets

  # Re-render when the client secret is replaced, or when anything else feeding the file changes
  # (the app's client ID, the secret's name/namespace, a template, or a shared random value).
  # Hashed so the plan does not print the credential.
  triggers_replace = {
    spec = sha256(local.k8s_secret_specs[each.key])
  }

  provisioner "local-exec" {
    command     = "${local.repo_root}/scripts/render-sops-secret.sh '${local.repo_root}/${each.key}'"
    interpreter = ["/bin/bash", "-c"]
    # Passed through the environment rather than argv so the values are not visible in the
    # process list, matching the approach in components/virtual-machines/ansible.sh.tpl.
    environment = {
      SECRET_SPEC = local.k8s_secret_specs[each.key]
    }
  }
}

# Deferred to apply by depends_on, so it reads the file after any re-render. When nothing changed
# the provisioner does not run and this simply reads the file from the git checkout, which then
# matches what is already committed and produces no diff below.
data "local_file" "sops_secret" {
  for_each   = local.k8s_secrets
  filename   = "${local.repo_root}/${each.key}"
  depends_on = [terraform_data.sops_secret]
}

resource "github_repository_file" "sops_secret" {
  for_each            = local.k8s_secrets
  repository          = data.github_repository.this.name
  branch              = "main"
  file                = each.key
  content             = data.local_file.sops_secret[each.key].content
  commit_message      = "chore: sync ${each.value.app} SOPS secret"
  overwrite_on_create = true
}
