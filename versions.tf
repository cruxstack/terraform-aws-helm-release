terraform {
  required_version = ">= 1.11" # write-only `set_wo` and ephemeral inputs

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
      version = ">= 3.3.0" # `moved` from `kubernetes_namespace`
    }
  }
}
