# =================================================================== locals ===

locals {
  enabled            = module.this.enabled
  iam_role_enabled   = local.enabled && var.iam_role_enabled
  iam_policy_enabled = local.iam_role_enabled && var.iam_policy_enabled

  create_namespace          = local.enabled && coalesce(var.create_namespace_with_kubernetes, var.create_namespace, false)
  create_namespace_via_k8s  = local.enabled && var.create_namespace_with_kubernetes == true
  create_namespace_via_helm = local.create_namespace && !local.create_namespace_via_k8s

  release_name = coalesce(var.release_name, module.this.name, var.chart)

  service_account_role_arn_set = local.iam_role_enabled && var.service_account_role_arn_annotation_enabled ? [{
    name  = var.service_account_set_key_path
    value = module.eks_iam_role.service_account_role_arn
    type  = "string"
  }] : []

  set = concat(var.set, local.service_account_role_arn_set)
}

# ---------------------------------------------------------------------- iam ---

module "eks_iam_policy" {
  source  = "cloudposse/iam-policy/aws"
  version = "2.0.2"

  enabled = local.iam_policy_enabled

  iam_policy                    = var.iam_policy
  iam_source_policy_documents   = var.iam_source_policy_documents
  iam_override_policy_documents = var.iam_override_policy_documents
  iam_source_json_url           = var.iam_source_json_url
  iam_policy_statements         = var.iam_policy_statements

  context = module.this.context
}

module "eks_iam_role" {
  source  = "cloudposse/eks-iam-role/aws"
  version = "2.2.1"

  enabled = local.iam_role_enabled

  aws_account_number          = var.aws_account_number
  aws_iam_policy_document     = local.iam_policy_enabled ? [module.eks_iam_policy.json] : []
  aws_partition               = var.aws_partition
  eks_cluster_oidc_issuer_url = var.eks_cluster_oidc_issuer_url
  managed_policy_arns         = var.iam_managed_policy_arns
  permissions_boundary        = var.permissions_boundary
  service_account_name        = var.service_account_name
  service_account_namespace   = var.service_account_namespace

  context = module.this.context

  depends_on = [module.eks_iam_policy]
}

# ---------------------------------------------------------------- namespace ---

resource "kubernetes_namespace_v1" "default" {
  count = local.create_namespace_via_k8s ? 1 : 0

  metadata {
    name        = var.kubernetes_namespace
    annotations = var.kubernetes_namespace_annotations
    labels      = var.kubernetes_namespace_labels
  }

  # keep the role until finalizers that need it have run
  depends_on = [module.eks_iam_role]
}

moved {
  from = kubernetes_namespace.default
  to   = kubernetes_namespace_v1.default
}

# ------------------------------------------------------------------ release ---

resource "helm_release" "this" {
  count = local.enabled ? 1 : 0

  name        = local.release_name
  chart       = var.chart
  description = var.description
  devel       = var.devel
  version     = var.chart_version

  repository           = var.repository
  repository_ca_file   = var.repository_ca_file
  repository_cert_file = var.repository_cert_file
  repository_key_file  = var.repository_key_file
  repository_password  = var.repository_password
  repository_username  = var.repository_username
  pass_credentials     = var.pass_credentials

  create_namespace = local.create_namespace_via_helm
  namespace        = var.kubernetes_namespace

  atomic                     = var.atomic
  cleanup_on_fail            = var.cleanup_on_fail
  dependency_update          = var.dependency_update
  disable_crd_hooks          = var.disable_crd_hooks
  disable_openapi_validation = var.disable_openapi_validation
  disable_webhooks           = var.disable_webhooks
  force_update               = var.force_update
  keyring                    = var.keyring
  lint                       = var.lint
  max_history                = var.max_history
  recreate_pods              = var.recreate_pods
  render_subchart_notes      = var.render_subchart_notes
  replace                    = var.replace
  reset_values               = var.reset_values
  reuse_values               = var.reuse_values
  skip_crds                  = var.skip_crds
  take_ownership             = var.take_ownership
  timeout                    = var.timeout
  upgrade_install            = var.upgrade_install
  verify                     = var.verify
  wait                       = var.wait
  wait_for_jobs              = var.wait_for_jobs

  values          = var.values
  set             = local.set
  set_list        = var.set_list
  set_sensitive   = var.set_sensitive
  set_wo          = length(var.set_wo) > 0 ? var.set_wo : null
  set_wo_revision = var.set_wo_revision

  postrender = var.postrender_binary_path == null ? null : {
    binary_path = var.postrender_binary_path
    args        = var.postrender_args
  }

  depends_on = [
    module.eks_iam_role,
    kubernetes_namespace_v1.default,
  ]
}
