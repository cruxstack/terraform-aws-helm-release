output "metadata" {
  description = "Status of the deployed release: `name`, `namespace`, `revision`, `chart`, `version`, `app_version`, `values`, `notes`, `first_deployed`, and `last_deployed`."
  value       = one(helm_release.this[*].metadata)
}

output "service_account_namespace" {
  description = "Namespace of the service account allowed to assume the role."
  value       = module.eks_iam_role.service_account_namespace
}

output "service_account_name" {
  description = "Name of the service account allowed to assume the role."
  value       = module.eks_iam_role.service_account_name
}

output "service_account_role_name" {
  description = "IAM role name."
  value       = module.eks_iam_role.service_account_role_name
}

output "service_account_role_unique_id" {
  description = "IAM role unique ID."
  value       = module.eks_iam_role.service_account_role_unique_id
}

output "service_account_role_arn" {
  description = "IAM role ARN."
  value       = module.eks_iam_role.service_account_role_arn
}

output "service_account_policy_name" {
  description = "IAM policy name."
  value       = module.eks_iam_role.service_account_policy_name
}

output "service_account_policy_id" {
  description = "IAM policy ID."
  value       = module.eks_iam_role.service_account_policy_id
}

output "service_account_policy_arn" {
  description = "IAM policy ARN."
  value       = module.eks_iam_role.service_account_policy_arn
}
