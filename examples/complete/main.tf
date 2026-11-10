terraform {
  required_version = ">= 1.11"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.3.0"
    }
  }
}

variable "eks_cluster_name" {
  type = string
}

provider "aws" {
  region = "us-east-1"
}

data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

locals {
  eks_exec = {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name]
  }
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec                   = local.eks_exec
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = local.eks_exec.api_version
    command     = local.eks_exec.command
    args        = local.eks_exec.args
  }
}

module "external_dns" {
  source = "../../"

  namespace = "eg"
  stage     = "dev"
  name      = "external-dns"

  chart         = "external-dns"
  repository    = "https://kubernetes-sigs.github.io/external-dns"
  chart_version = "1.19.0"

  kubernetes_namespace             = "external-dns"
  create_namespace_with_kubernetes = true
  kubernetes_namespace_labels      = { team = "platform" }

  iam_role_enabled            = true
  eks_cluster_oidc_issuer_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  service_account_name        = "external-dns"
  service_account_namespace   = "external-dns"
  iam_policy = [{
    statements = [{
      sid       = "ChangeRecords"
      actions   = ["route53:ChangeResourceRecordSets"]
      resources = ["arn:aws:route53:::hostedzone/*"]
      }, {
      sid       = "ListZones"
      actions   = ["route53:ListHostedZones", "route53:ListResourceRecordSets", "route53:ListTagsForResources"]
      resources = ["*"]
    }]
  }]

  values = [yamlencode({
    serviceAccount = { name = "external-dns" }
    provider       = { name = "aws" }
  })]
  set = [{ name = "policy", value = "sync" }]

  wait    = true
  atomic  = true
  timeout = 300
}

output "metadata" {
  value = module.external_dns.metadata
}
