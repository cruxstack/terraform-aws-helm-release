# terraform-aws-helm-release

This Terraform module deploys a Helm chart to an Amazon EKS cluster, with an
optional IAM role for the chart's service account (IRSA) and an optional
namespace with labels and annotations.

It targets the Helm provider v3 and the Kubernetes provider v3. Its inputs,
outputs, and resource addresses match
[`cloudposse/terraform-aws-helm-release`](https://github.com/cloudposse/terraform-aws-helm-release)
v0.10, so existing callers can switch to it without moving state. See
[Migrating from cloudposse/helm-release](#migrating-from-cloudpossehelm-release).

## Features

- `helm_release` with every Helm provider v3 option, including `set_list`,
  write-only `set_wo`, `take_ownership`, `upgrade_install`, and post-renderer
  arguments
- IAM role for the chart's service account, built from inline statements,
  JSON documents, or managed policy ARNs, with its ARN passed to the chart
- Namespace created by the Kubernetes provider (`kubernetes_namespace_v1`)
  with labels and annotations, or by Helm
- Naming and tags via `cloudposse/label/null`

## Usage

```hcl
module "external_dns" {
  source  = "cruxstack/helm-release/aws"
  version = "x.x.x"

  name = "external-dns"

  chart         = "external-dns"
  repository    = "https://kubernetes-sigs.github.io/external-dns"
  chart_version = "1.19.0"

  kubernetes_namespace             = "external-dns"
  create_namespace_with_kubernetes = true

  iam_role_enabled            = true
  eks_cluster_oidc_issuer_url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  service_account_name        = "external-dns"
  service_account_namespace   = "external-dns"
  iam_policy = [{
    statements = [{
      actions   = ["route53:ChangeResourceRecordSets"]
      resources = ["arn:aws:route53:::hostedzone/*"]
    }]
  }]

  values = [yamlencode({ provider = { name = "aws" } })]
  set    = [{ name = "policy", value = "sync" }]
}
```

The caller configures the `helm` and `kubernetes` providers. With the Helm
provider v3, `kubernetes` and its `exec` are attributes, not blocks:

```hcl
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.aws_eks_cluster.this.name]
    }
  }
}
```

[`examples/complete`](examples/complete) has both providers configured.

### IAM role

With `iam_role_enabled = true`, the module creates a role that the service
account `service_account_namespace`/`service_account_name` can assume through
the cluster's OIDC provider. Leaving either one `null` allows every value
(`*`). The role gets a policy built from `iam_policy`,
`iam_source_policy_documents`, `iam_override_policy_documents`, and
`iam_source_json_url`, plus any `iam_managed_policy_arns`.

The module passes the role ARN to the chart at `service_account_set_key_path`
(default `serviceAccount.annotations.eks\.amazonaws\.com/role-arn`). Set
`service_account_role_arn_annotation_enabled = false` when the chart takes the
ARN elsewhere.

### Namespace

| Setting                                   | Who creates the namespace | Labels and annotations | On destroy                |
| ----------------------------------------- | ------------------------- | :--------------------: | ------------------------- |
| `create_namespace_with_kubernetes = true` | Kubernetes provider       |          yes           | deleted after the release |
| `create_namespace = true`                 | Helm                      |           no           | kept                      |
| neither                                   | must already exist        |           -            | -                         |

### Write-only values

`set_wo` values reach Helm but never Terraform state or plans. The input is
ephemeral, so it accepts ephemeral values such as secrets from an ephemeral
resource. Terraform cannot detect changes to them, so increase
`set_wo_revision` to apply new values. Needs Terraform or OpenTofu 1.11 or
later.

## Inputs

In addition to the variables below, this module includes the optional
variables of [`cloudposse/label/null`](https://registry.terraform.io/modules/cloudposse/label/null/latest)
(`name`, `tags`, `enabled`, and others). `enabled = false` creates nothing.

### Release

| Name                     | Description                                                 |      Type      | Default | Required |
| ------------------------ | ----------------------------------------------------------- | :------------: | :-----: | :------: |
| `chart`                  | chart name, URL, OCI reference, or local path               |    `string`    |   n/a   |   yes    |
| `chart_version`          | chart version; `null` installs the latest                   |    `string`    | `null`  |    no    |
| `repository`             | chart repository URL                                        |    `string`    | `null`  |    no    |
| `release_name`           | release name; defaults to the context `name`, then `chart`  |    `string`    |  `""`   |    no    |
| `kubernetes_namespace`   | namespace of the release                                    |    `string`    | `null`  |    no    |
| `values`                 | values as YAML documents, merged in order                   | `list(string)` | `null`  |    no    |
| `set`                    | values by key path (`name`, `value`, optional `type`)       | `list(object)` |  `[]`   |    no    |
| `set_list`               | list values by key path (`name`, `value`)                   | `list(object)` |  `[]`   |    no    |
| `set_sensitive`          | values by key path, redacted from plans but stored in state | `list(object)` |  `[]`   |    no    |
| `set_wo`                 | values by key path, never stored (ephemeral)                | `list(object)` |  `[]`   |    no    |
| `set_wo_revision`        | increase to apply changed `set_wo` values                   |    `number`    | `null`  |    no    |
| `postrender_binary_path` | post-renderer executable                                    |    `string`    | `null`  |    no    |
| `postrender_args`        | post-renderer arguments                                     | `list(string)` | `null`  |    no    |

`atomic`, `cleanup_on_fail`, `dependency_update`, `description`, `devel`,
`disable_crd_hooks`, `disable_openapi_validation`, `disable_webhooks`,
`force_update`, `keyring`, `lint`, `max_history`, `pass_credentials`,
`recreate_pods`, `render_subchart_notes`, `replace`, `repository_ca_file`,
`repository_cert_file`, `repository_key_file`, `repository_password`,
`repository_username`, `reset_values`, `reuse_values`, `skip_crds`,
`take_ownership`, `timeout`, `upgrade_install`, `verify`, `wait`, and
`wait_for_jobs` pass through to the
[`helm_release`](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release)
argument of the same name and default to `null`, which keeps the provider's
default.

### Namespace

| Name                               | Description                                        |     Type      | Default | Required |
| ---------------------------------- | -------------------------------------------------- | :-----------: | :-----: | :------: |
| `create_namespace_with_kubernetes` | create the namespace with the Kubernetes provider  |    `bool`     | `null`  |    no    |
| `create_namespace`                 | have Helm create the namespace                     |    `bool`     | `null`  |    no    |
| `kubernetes_namespace_labels`      | labels of a namespace created with Kubernetes      | `map(string)` |  `{}`   |    no    |
| `kubernetes_namespace_annotations` | annotations of a namespace created with Kubernetes | `map(string)` |  `{}`   |    no    |

### IAM

| Name                                          | Description                                                 |      Type      |     Default     |  Required   |
| --------------------------------------------- | ----------------------------------------------------------- | :------------: | :-------------: | :---------: |
| `iam_role_enabled`                            | create an IRSA role for the service account                 |     `bool`     |     `false`     |     no      |
| `eks_cluster_oidc_issuer_url`                 | cluster OIDC issuer URL                                     |    `string`    |     `null`      | with a role |
| `service_account_name`                        | service account that can assume the role; `null` allows all |    `string`    |     `null`      |     no      |
| `service_account_namespace`                   | its namespace; `null` allows all                            |    `string`    |     `null`      |     no      |
| `iam_policy_enabled`                          | create and attach a policy from the `iam_*` inputs          |     `bool`     |     `true`      |     no      |
| `iam_policy`                                  | policy statements as objects                                | `list(object)` |      `[]`       |     no      |
| `iam_source_policy_documents`                 | JSON documents merged into the policy                       | `list(string)` |     `null`      |     no      |
| `iam_override_policy_documents`               | JSON documents merged last, replacing matching `sid`s       | `list(string)` |     `null`      |     no      |
| `iam_source_json_url`                         | URL of a JSON document merged into the policy               |    `string`    |     `null`      |     no      |
| `iam_policy_statements`                       | deprecated; use `iam_policy`                                |     `any`      |      `{}`       |     no      |
| `iam_managed_policy_arns`                     | managed policies attached to the role                       | `set(string)`  |      `[]`       |     no      |
| `permissions_boundary`                        | permissions boundary ARN of the role                        |    `string`    |     `null`      |     no      |
| `service_account_role_arn_annotation_enabled` | pass the role ARN to the chart                              |     `bool`     |     `true`      |     no      |
| `service_account_set_key_path`                | chart value that receives the role ARN                      |    `string`    | IRSA annotation |     no      |
| `aws_account_number`                          | account of the cluster; defaults to the provider's account  |    `string`    |     `null`      |     no      |
| `aws_partition`                               | partition of the role ARN                                   |    `string`    |     `"aws"`     |     no      |

## Outputs

| Name                             | Description                                                                                                                                                               |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `metadata`                       | release status object (`name`, `namespace`, `revision`, `chart`, `version`, `app_version`, `values`, `notes`, `first_deployed`, `last_deployed`), or `null` when disabled |
| `service_account_role_arn`       | IAM role ARN                                                                                                                                                              |
| `service_account_role_name`      | IAM role name                                                                                                                                                             |
| `service_account_role_unique_id` | IAM role unique ID                                                                                                                                                        |
| `service_account_policy_arn`     | IAM policy ARN                                                                                                                                                            |
| `service_account_policy_id`      | IAM policy ID                                                                                                                                                             |
| `service_account_policy_name`    | IAM policy name                                                                                                                                                           |
| `service_account_name`           | service account allowed to assume the role                                                                                                                                |
| `service_account_namespace`      | namespace of that service account                                                                                                                                         |

## Migrating from cloudposse/helm-release

The module keeps the v0.10 inputs and the addresses of `helm_release.this`,
`module.eks_iam_role`, and `module.eks_iam_policy`, and moves
`kubernetes_namespace.default` to `kubernetes_namespace_v1.default` with a
`moved` block. Switching needs no state commands:

1. Replace the module source:

   ```hcl
   source  = "cruxstack/helm-release/aws"
   version = "x.x.x"
   ```

2. Require the Helm provider v3 and Kubernetes provider v3.3 or later, then
   run `terraform init -upgrade`. The Helm provider upgrades existing release
   state itself.

3. Rewrite the `helm` provider block in v3 syntax: `kubernetes = { ... }`,
   `exec = { ... }` (a conditional object or `null` instead of a `dynamic`
   block), and `experiments = { ... }`.

4. `metadata` is now an object instead of a one-element list. Replace
   `one(module.x.metadata)` or `module.x.metadata[0]` with `module.x.metadata`.
   `try(one(module.x.metadata), null)` does not fail, it returns `null`.

Other changes:

- `set` and `set_sensitive` entries no longer need `type`.
- `values` is `list(string)` instead of `any`.
- An empty `kubernetes_namespace_labels` or `kubernetes_namespace_annotations`
  is sent as `null`, because the Kubernetes provider v3.3 treats an explicit
  empty map as a change.
- The module needs Terraform or OpenTofu 1.11 or later.

## Requirements

| Name                   | Version    |
| ---------------------- | ---------- |
| Terraform or OpenTofu  | `>= 1.11`  |
| `hashicorp/aws`        | `>= 5.0`   |
| `hashicorp/helm`       | `>= 3.1.1` |
| `hashicorp/kubernetes` | `>= 3.3.0` |

## License

MIT. The inputs and behavior follow
[`cloudposse/terraform-aws-helm-release`](https://github.com/cloudposse/terraform-aws-helm-release)
(Apache-2.0) so it can replace that module.
