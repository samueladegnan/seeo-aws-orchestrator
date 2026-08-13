# SEEO infrastructure

I organized the Terraform code as four independently runnable provider foundations. Credentials for one cloud are not needed to validate another, and the Rails control plane consumes the selected stack's normalized network and identity outputs.

## Provider stacks

| Provider | Foundation | Stack directory |
| --- | --- | --- |
| AWS | VPC, public subnets, security groups, IAM, state tables, secret, logs, and container registry | `infrastructure/` |
| Azure | Resource group, virtual network, subnet, and identity-ready foundation | `infrastructure/stacks/azure/` |
| Google Cloud | VPC network, subnetwork, and service-account-ready foundation | `infrastructure/stacks/gcp/` |
| OCI | VCN, subnet, and compartment-scoped foundation | `infrastructure/stacks/oci/` |

The non-AWS roots intentionally stop at foundations: their network and identity outputs are complete enough to feed a runner, but compute image catalogs, workload identity bindings, and provider-specific VM policies still belong in a deployment-specific layer. This keeps `terraform validate` credential-free and prevents a portfolio demo from creating billable resources accidentally.

The AWS root has four documented Checkov exceptions because it is a foundation, not a complete production deployment: public subnets support the disposable runner, outbound access is needed for provider CLIs, flow-log destinations belong to the observability layer, and the exported security group is attached by the runtime layer. CI passes those four check IDs only for the AWS matrix entry. Azure, Google Cloud, and OCI remain strict, and the Checkov job still fails on every other finding. Revalidate these scoped exceptions when upgrading Checkov.

Each stack exports a network identifier and subnet identifier that can be passed to the matching runtime adapter through `SEEO_<PROVIDER>_NETWORK_ID` and `SEEO_<PROVIDER>_SUBNET_ID`. The control-plane database is owned by Rails and is intentionally separate from provider infrastructure state.

## Authentication

Use each provider's standard authentication path. Never commit credentials to Terraform files or state.

- AWS: `AWS_PROFILE`, environment credentials, or an IAM role
- Azure: `az login`, managed identity, or `ARM_*` service-principal variables
- Google Cloud: Application Default Credentials or `GOOGLE_CREDENTIALS`
- OCI: `~/.oci/config` or the OCI provider's standard environment variables

## Validate a stack

From any stack directory:

```bash
terraform fmt -check -recursive
terraform init
terraform validate
terraform plan
```

CI runs formatting, initialization, validation, and Checkov checks for all four roots. Apply only the providers enabled for the target deployment, and review every plan before changing cloud resources.
