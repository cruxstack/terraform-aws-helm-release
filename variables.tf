# ---------------------------------------------------------------------- iam ---

variable "iam_role_enabled" {
  description = "Create an IAM role for a Kubernetes service account through EKS IAM Roles for Service Accounts (IRSA)."
  type        = bool
  default     = false
  nullable    = false
}

variable "iam_policy_enabled" {
  description = "Create an IAM policy from the `iam_*` policy inputs and attach it to the role. Only used when `iam_role_enabled` is `true`."
  type        = bool
  default     = true
  nullable    = false
}

variable "iam_policy" {
  description = "IAM policy as a list of objects shaped like the `aws_iam_policy_document` data source, without its source and override documents."
  type = list(object({
    policy_id = optional(string, null)
    version   = optional(string, null)
    statements = list(object({
      sid           = optional(string, null)
      effect        = optional(string, null)
      actions       = optional(list(string), null)
      not_actions   = optional(list(string), null)
      resources     = optional(list(string), null)
      not_resources = optional(list(string), null)
      conditions = optional(list(object({
        test     = string
        variable = string
        values   = list(string)
      })), [])
      principals = optional(list(object({
        type        = string
        identifiers = list(string)
      })), [])
      not_principals = optional(list(object({
        type        = string
        identifiers = list(string)
      })), [])
    }))
  }))
  default  = []
  nullable = false
}

variable "iam_source_policy_documents" {
  description = "IAM policy JSON documents merged into the role policy. Statements with the same `sid` must be identical."
  type        = list(string)
  default     = null
}

variable "iam_override_policy_documents" {
  description = "IAM policy JSON documents merged into the role policy last. Statements with the same `sid` replace earlier ones."
  type        = list(string)
  default     = null
}

variable "iam_source_json_url" {
  description = "URL of an IAM policy JSON document to download and merge into the role policy."
  type        = string
  default     = null
}

variable "iam_policy_statements" {
  description = "Deprecated: use `iam_policy`. IAM policy statements as a list or as a map keyed by `sid`."
  type        = any
  default     = {}
}

variable "iam_managed_policy_arns" {
  description = "ARNs of managed IAM policies to attach to the role."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "permissions_boundary" {
  description = "ARN of the permissions boundary for the role."
  type        = string
  default     = null
}

variable "aws_account_number" {
  description = "AWS account number of the EKS cluster. Defaults to the account of the AWS provider."
  type        = string
  default     = null
}

variable "aws_partition" {
  description = "AWS partition of the role ARN: `aws`, `aws-cn`, or `aws-us-gov`."
  type        = string
  default     = "aws"
  nullable    = false
}

variable "eks_cluster_oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster, with or without `https://`. Required when `iam_role_enabled` is `true`."
  type        = string
  default     = null
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account allowed to assume the role. `null` allows every service account in `service_account_namespace`."
  type        = string
  default     = null
}

variable "service_account_namespace" {
  description = "Namespace of the Kubernetes service account allowed to assume the role. `null` allows `service_account_name` in every namespace."
  type        = string
  default     = null
}

variable "service_account_role_arn_annotation_enabled" {
  description = "Pass the role ARN to the chart at `service_account_set_key_path`. Only used when `iam_role_enabled` is `true`."
  type        = bool
  default     = true
  nullable    = false
}

variable "service_account_set_key_path" {
  description = "Chart value that receives the role ARN."
  type        = string
  default     = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
  nullable    = false
}

# ---------------------------------------------------------------- namespace ---

variable "kubernetes_namespace" {
  description = "Namespace of the release."
  type        = string
  default     = null
}

variable "create_namespace_with_kubernetes" {
  description = "Create `kubernetes_namespace` with the Kubernetes provider, which supports labels and annotations."
  type        = bool
  default     = null
}

variable "create_namespace" {
  description = "Have Helm create `kubernetes_namespace` when it does not exist. Ignored when `create_namespace_with_kubernetes` is `true`."
  type        = bool
  default     = null
}

variable "kubernetes_namespace_labels" {
  description = "Labels of the namespace created by `create_namespace_with_kubernetes`."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "kubernetes_namespace_annotations" {
  description = "Annotations of the namespace created by `create_namespace_with_kubernetes`."
  type        = map(string)
  default     = {}
  nullable    = false
}

# ------------------------------------------------------------------ release ---

variable "chart" {
  description = "Chart name, chart URL, OCI reference, or local path. Combined with `repository` when that is set."
  type        = string
}

variable "chart_version" {
  description = "Chart version. `null` installs the latest version."
  type        = string
  default     = null
}

variable "release_name" {
  description = "Release name. Defaults to the context `name`, then to `chart`."
  type        = string
  default     = ""
  nullable    = false
}

variable "description" {
  description = "Release description."
  type        = string
  default     = null
}

variable "devel" {
  description = "Also consider development versions. Ignored when `chart_version` is set."
  type        = bool
  default     = null
}

variable "repository" {
  description = "Chart repository URL."
  type        = string
  default     = null
}

variable "repository_ca_file" {
  description = "CA bundle file for the chart repository."
  type        = string
  default     = null
}

variable "repository_cert_file" {
  description = "Client certificate file for the chart repository."
  type        = string
  default     = null
}

variable "repository_key_file" {
  description = "Client key file for the chart repository."
  type        = string
  default     = null
}

variable "repository_username" {
  description = "Username for the chart repository."
  type        = string
  default     = null
}

variable "repository_password" {
  description = "Password for the chart repository."
  type        = string
  default     = null
  sensitive   = true
}

variable "pass_credentials" {
  description = "Pass repository credentials to every domain the chart is fetched from."
  type        = bool
  default     = null
}

variable "values" {
  description = "Chart values as YAML documents, merged in order."
  type        = list(string)
  default     = null
}

variable "set" {
  description = "Chart values set by key path. `type` is `auto`, `string`, or `literal`."
  type = list(object({
    name  = string
    value = optional(string)
    type  = optional(string)
  }))
  default  = []
  nullable = false
}

variable "set_list" {
  description = "Chart list values set by key path."
  type = list(object({
    name  = string
    value = list(string)
  }))
  default  = []
  nullable = false
}

variable "set_sensitive" {
  description = "Chart values set by key path and redacted from the plan. They are still stored in state."
  type = list(object({
    name  = string
    value = string
    type  = optional(string)
  }))
  default   = []
  nullable  = false
  sensitive = true
}

variable "set_wo" {
  description = "Chart values set by key path and never stored in state. Change `set_wo_revision` to apply new values."
  type = list(object({
    name  = string
    value = string
    type  = optional(string)
  }))
  default   = []
  nullable  = false
  ephemeral = true
}

variable "set_wo_revision" {
  description = "Revision of `set_wo`. Increase it to apply changed `set_wo` values."
  type        = number
  default     = null
}

variable "postrender_binary_path" {
  description = "Path to a post-renderer executable that receives the rendered manifests."
  type        = string
  default     = null
}

variable "postrender_args" {
  description = "Arguments for `postrender_binary_path`."
  type        = list(string)
  default     = null
}

variable "atomic" {
  description = "Roll back the release when an install or upgrade fails. Turns on `wait`."
  type        = bool
  default     = null
}

variable "cleanup_on_fail" {
  description = "Delete resources created by a failed upgrade."
  type        = bool
  default     = null
}

variable "dependency_update" {
  description = "Update chart dependencies before installing."
  type        = bool
  default     = null
}

variable "disable_crd_hooks" {
  description = "Skip the CRD install hooks."
  type        = bool
  default     = null
}

variable "disable_openapi_validation" {
  description = "Skip validating rendered manifests against the Kubernetes OpenAPI schema."
  type        = bool
  default     = null
}

variable "disable_webhooks" {
  description = "Skip running chart hooks."
  type        = bool
  default     = null
}

variable "force_update" {
  description = "Force resource updates through delete and recreate."
  type        = bool
  default     = null
}

variable "keyring" {
  description = "Public keys used to verify the chart when `verify` is `true`."
  type        = string
  default     = null
}

variable "lint" {
  description = "Lint the chart before installing."
  type        = bool
  default     = null
}

variable "max_history" {
  description = "Release revisions to keep. `0` keeps every revision."
  type        = number
  default     = null
}

variable "recreate_pods" {
  description = "Restart pods during an upgrade or rollback."
  type        = bool
  default     = null
}

variable "render_subchart_notes" {
  description = "Render subchart notes with the parent chart notes."
  type        = bool
  default     = null
}

variable "replace" {
  description = "Reuse the release name even when it is still in history."
  type        = bool
  default     = null
}

variable "reset_values" {
  description = "Reset values to the chart defaults during an upgrade."
  type        = bool
  default     = null
}

variable "reuse_values" {
  description = "Reuse the last release values during an upgrade and merge overrides. Ignored when `reset_values` is `true`."
  type        = bool
  default     = null
}

variable "skip_crds" {
  description = "Skip installing CRDs from the chart `crds` directory."
  type        = bool
  default     = null
}

variable "take_ownership" {
  description = "Adopt existing resources that lack Helm ownership annotations instead of failing."
  type        = bool
  default     = null
}

variable "timeout" {
  description = "Seconds to wait for each Kubernetes operation."
  type        = number
  default     = null
}

variable "upgrade_install" {
  description = "Upgrade the release in place when it already exists, as `helm upgrade --install` does."
  type        = bool
  default     = null
}

variable "verify" {
  description = "Verify the chart signature before installing."
  type        = bool
  default     = null
}

variable "wait" {
  description = "Wait until every resource is ready before marking the release successful."
  type        = bool
  default     = null
}

variable "wait_for_jobs" {
  description = "Also wait for jobs to complete when `wait` is `true`."
  type        = bool
  default     = null
}
