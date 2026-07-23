# SEEO Follow-Up Manual Steps

This page documents the three follow-up tracks for SEEO, what is automated in code, and what you must do manually.

## Track 1: CI/CD + Integration Tests (moto)

### What the code provides

- `.github/workflows/ci.yml` runs pytest on every push/PR.
- `backend/tests/test_aws_service.py` uses `moto` to mock EC2, DynamoDB, and Secrets Manager.
- `backend/pyproject.toml` has `moto` as a dev dependency.

### Manual steps

1. Open the repo on GitHub.
2. Go to **Settings → Actions → General** and make sure workflows are allowed.
3. Push the code; the CI badge should appear green.
4. To run locally:
   ```bash
   cd backend
   pip install -r requirements.txt
   pip install -e ".[dev]"
   pytest
   ```

## Track 2: Deploy to Real AWS

### What the code provides

- Terraform modules in `infrastructure/`.
- `.env.example` with every setting you need.

### Manual steps

1. Install Terraform and the AWS CLI.
2. Configure AWS credentials (`aws configure`).
3. Copy `backend/.env.example` to `backend/.env` and fill in values from Terraform outputs.
4. Deploy infrastructure:
   ```bash
   cd infrastructure
   terraform init
   terraform plan
   terraform apply
   ```
5. Note the outputs: `security_group_id`, `subnet_ids`, `instance_profile_name`.
6. Run the backend:
   ```bash
   cd backend
   uvicorn app.main:app --host 0.0.0.0 --port 8000
   ```
7. Request an environment:
   ```bash
   curl -X POST http://localhost:8000/environments \
     -H "X-API-Key: your-key" \
     -d '{"project_name":"demo","ttl_minutes":60}'
   ```

## Track 3: Hardened Custom AMI with Packer

### What the code provides

- `backend/packer/seeo.pkr.hcl` builds an Amazon Linux 2023 AMI.
- `backend/packer/scripts/bootstrap.sh` installs the AWS CLI, CloudWatch agent, and a bootstrap service.

### Manual steps

1. Install [Packer](https://www.packer.io/).
2. Set your AWS region and base AMI in `seeo.pkr.hcl`.
3. Build the AMI:
   ```bash
   cd backend/packer
   packer init .
   packer build seeo.pkr.hcl
   ```
4. Copy the resulting AMI ID into your `.env` as `EC2_AMI_ID`.
5. Re-deploy the backend.

## GitHub Pages Setup

The repo already contains the GitHub Pages configuration.

### Manual steps

1. Go to **Settings → Pages** in the GitHub repo.
2. Under **Build and deployment**, choose **Source: GitHub Actions**.
3. Push to `main`; the `.github/workflows/pages.yml` workflow will build and deploy the `docs/` folder to `https://samueladegnan.github.io/seeo-aws-orchestrator/`.
