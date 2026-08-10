# SEEO Backend (Ruby on Rails)

The Rails API is the control plane for short-lived environments across AWS, Azure, Google Cloud, and OCI. It authenticates tenants, evaluates provider-aware policy, persists provider-neutral lifecycle state, delegates VM operations to a cloud adapter, streams updates, estimates cost, and expires resources through a scheduled cleanup job.

## Requirements

- Ruby 3.3+
- Bundler
- Docker, or Ruby and the project dependencies installed locally
- A selected provider CLI runner (`aws`, `az`, `gcloud`, or `oci`) and short-lived credentials/workload identity for adapters used outside mock mode

## Setup

```bash
cd backend
cp .env.example .env
bundle install
bin/rails db:create db:migrate
bin/rails db:seed   # optional: creates a default team, project, and admin user
bin/rails server
```

## Provider configuration

| Variable | Description | Default |
|---|---|---|
| `SEEO_DEFAULT_PROVIDER` | Provider selected when a request omits `provider` | `aws` |
| `SEEO_ALLOWED_PROVIDERS` | Comma-separated provider allow-list | `aws,azure,gcp,oci` |
| `SEEO_MOCK_MODE` | Use the in-memory adapter for every configured provider | `true` in development |
| `SEEO_APP_VERSION` | Version reported by `GET /health` | `0.3.0` |
| `SEEO_<PROVIDER>_REGION` | Default region for `AWS`, `AZURE`, `GCP`, or `OCI` | provider catalog |
| `SEEO_<PROVIDER>_PROJECT` | Provider account, subscription, project, or compartment reference | none |
| `SEEO_<PROVIDER>_NETWORK_ID` | Terraform-created network identifier | none |
| `SEEO_<PROVIDER>_SUBNET_ID` | Terraform-created subnet identifier | none |
| `SEEO_<PROVIDER>_CREDENTIALS` | Reference to provider credentials or workload identity | none |
| `SEEO_AWS_IMAGE_ID` | AWS image used by the AWS CLI adapter | none in mock mode |
| `SEEO_AWS_SECURITY_GROUP_ID` | AWS security group used by the AWS CLI adapter | none in mock mode |
| `SEEO_AZURE_RESOURCE_GROUP` | Azure resource group for VM operations | none in mock mode |
| `SEEO_GCP_PROJECT` | Google Cloud project for VM operations | none in mock mode |
| `SEEO_GCP_ZONE` | Explicit Google Cloud zone; regions do not imply a zone | none in mock mode |
| `SEEO_OCI_COMPARTMENT_ID` | OCI compartment for compute operations | none in mock mode |
| `SEEO_OCI_AVAILABILITY_DOMAIN` | OCI availability domain for instance launch | none in mock mode |
| `SEEO_OCI_IMAGE_ID` | OCI image OCID for instance launch | none in mock mode |
| `SEEO_API_KEY` | API key for local/mock service-account requests | local development only |
| `SEEO_JWT_SECRET` | Secret used to sign/verify JWT tenant tokens | local development only |
| `DATABASE_URL` | Rails control-plane database | `storage/development.sqlite3` |
| `SEEO_TTL_CHECK_INTERVAL_SECONDS` | TTL scan interval | `60` |

Provider adapters implement the same lifecycle methods: create, list, refresh, terminate, and cleanup. The public demo uses `MockCloudService`, which simulates all four providers without creating billable resources. Real mode uses the selected provider CLI and requires its credentials through workload identity or a secret manager, the CLI binary, network outputs, image settings, and provider-specific integration tests before disabling mock mode. The browser-visible demo key is never valid for real mode.

## Authentication

The API supports:

- **JWT tenant tokens:** `Authorization: Bearer <jwt>` for team-backed requests.
- **API key plus signed browser session:** local/mock demo access only. The browser session scopes records without exposing a real cloud credential.

ActionCable receives a separate signed token and derives the authorized team or browser-session stream on the server.

## Running locally

```bash
bundle exec rails server
```

For TTL monitoring in development, enqueue the monitor job manually or start the Solid Queue worker:

```bash
bundle exec rake solid_queue:start
```

## Running with Docker

```bash
docker build -t seeo-backend .
docker run --rm -p 3000:3000 --env-file .env seeo-backend
```

The default image is intended for the safe mock deployment. `Dockerfile.runner` provides a credential-free runner image with AWS CLI, Azure CLI, Google Cloud CLI, and OCI CLI installed. Authenticate that image only at runtime with workload identity, short-lived credentials, or mounted provider configuration; never add credentials to the image or repository.

## Provider contract tests

The adapter contract spec uses checked-in provider response fixtures and stubs `Open3.capture3`. It verifies command arguments and normalization for all four provider CLIs without contacting a cloud or requiring credentials:

```bash
bundle exec rspec spec/services/provider_adapter_contract_spec.rb
```

## Running tests and linting

```bash
bundle exec rspec
bundle exec rubocop
```

## Background jobs

`TtlMonitorJob` scans every enabled provider through the shared adapter contract. A provider that is not configured is logged and skipped; one failed cleanup does not prevent other expired environments from being processed.
