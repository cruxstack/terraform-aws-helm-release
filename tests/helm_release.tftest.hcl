# Runs the module against mocked providers, so these tests need no AWS account
# or Kubernetes cluster. Run with: terraform test

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111122223333"
    }
  }
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/test"
    }
  }
  mock_resource "aws_iam_policy" {
    defaults = {
      arn = "arn:aws:iam::111122223333:policy/test"
    }
  }
}

mock_provider "helm" {}

mock_provider "kubernetes" {}

variables {
  chart                = "metrics-server"
  repository           = "https://kubernetes-sigs.github.io/metrics-server"
  chart_version        = "3.13.0"
  kubernetes_namespace = "metrics-server"
}

run "defaults" {
  command = plan

  assert {
    condition = alltrue([
      length(helm_release.this) == 1,
      length(kubernetes_namespace_v1.default) == 0,
      helm_release.this[0].name == "metrics-server",
      helm_release.this[0].namespace == "metrics-server",
      helm_release.this[0].create_namespace == false,
      helm_release.this[0].set == null,
      helm_release.this[0].set_list == null,
      helm_release.this[0].postrender == null,
    ])
    error_message = "a bare release should plan only helm_release with no set values, namespace, or post-renderer"
  }

  assert {
    condition     = module.eks_iam_role.service_account_role_arn == null
    error_message = "no IAM role should be planned when iam_role_enabled is false"
  }
}

run "release_name" {
  command = plan

  variables {
    name         = "metrics"
    release_name = ""
  }

  assert {
    condition     = helm_release.this[0].name == "metrics"
    error_message = "the release name should default to the context name"
  }
}

run "disabled" {
  command = plan

  variables {
    enabled                          = false
    iam_role_enabled                 = true
    eks_cluster_oidc_issuer_url      = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    create_namespace_with_kubernetes = true
  }

  assert {
    condition = alltrue([
      length(helm_release.this) == 0,
      length(kubernetes_namespace_v1.default) == 0,
      module.eks_iam_role.service_account_role_arn == null,
    ])
    error_message = "a disabled module should plan nothing"
  }
}

run "irsa" {
  command = apply # mocked providers; the role ARN is known only after apply

  variables {
    name                        = "metrics-server"
    iam_role_enabled            = true
    eks_cluster_oidc_issuer_url = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    service_account_name        = "metrics-server"
    service_account_namespace   = "metrics-server"
    iam_source_policy_documents = [jsonencode({
      Version   = "2012-10-17"
      Statement = [{ Effect = "Allow", Action = ["ec2:DescribeInstances"], Resource = "*" }]
    })]
    set    = [{ name = "replicas", value = "2" }]
    set_wo = [] # ephemeral inputs must be set for both plan and apply
  }

  assert {
    condition = alltrue([
      [for s in helm_release.this[0].set : { name = s.name, value = s.value }] == [
        { name = "replicas", value = "2" },
        { name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn", value = "arn:aws:iam::111122223333:role/test" },
      ],
      helm_release.this[0].set[1].type == "string",
    ])
    error_message = "the role ARN should be appended to the caller's set values"
  }
}

run "irsa_without_annotation" {
  command = plan

  variables {
    iam_role_enabled                            = true
    eks_cluster_oidc_issuer_url                 = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLE"
    service_account_role_arn_annotation_enabled = false
  }

  assert {
    condition     = helm_release.this[0].set == null
    error_message = "the role ARN should not be set when the annotation is disabled"
  }
}

run "namespace_with_kubernetes" {
  command = plan

  variables {
    create_namespace_with_kubernetes = true
    kubernetes_namespace_labels      = { team = "platform" }
  }

  assert {
    condition = alltrue([
      length(kubernetes_namespace_v1.default) == 1,
      kubernetes_namespace_v1.default[0].metadata[0].name == "metrics-server",
      kubernetes_namespace_v1.default[0].metadata[0].labels == tomap({ team = "platform" }),
      kubernetes_namespace_v1.default[0].metadata[0].annotations == null,
      helm_release.this[0].create_namespace == false,
    ])
    error_message = "the namespace should be created by the Kubernetes provider, with empty maps left null"
  }
}

run "namespace_with_helm" {
  command = plan

  variables {
    create_namespace = true
  }

  assert {
    condition = alltrue([
      length(kubernetes_namespace_v1.default) == 0,
      helm_release.this[0].create_namespace == true,
    ])
    error_message = "the namespace should be created by Helm"
  }
}

run "set_list_and_postrender" {
  command = plan

  variables {
    set_list               = [{ name = "args", value = ["--kubelet-insecure-tls"] }]
    postrender_binary_path = "kustomize"
    postrender_args        = ["build", "."]
  }

  assert {
    condition = alltrue([
      helm_release.this[0].set_list == tolist([{ name = "args", value = tolist(["--kubelet-insecure-tls"]) }]),
      helm_release.this[0].postrender.binary_path == "kustomize",
      helm_release.this[0].postrender.args == tolist(["build", "."]),
    ])
    error_message = "set_list and postrender should pass through"
  }
}
