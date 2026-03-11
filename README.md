# AWS AI Cost Advisor

An AI-powered Lambda function that runs weekly, analyzes your AWS account's cost and resource utilization, and emails you a prioritized report — complete with Terraform snippets to fix each issue.

**Powered by Claude Opus with adaptive thinking.**

---

## How It Works

```
EventBridge Scheduler (weekly)
        │
        ▼
  Lambda Function
        │
        ├── Cost Explorer  → top services, tag breakdown, rightsizing recs
        ├── EC2 / EBS      → idle instances, unattached volumes, old snapshots
        └── RDS            → idle databases (< 1 connection / 14 days)
        │
        ▼
  Claude Opus API (adaptive thinking + streaming)
        │
        ▼
  Markdown Report  ──► S3 (full report + raw JSON)
                   ──► SNS → Email (2 000-char preview + S3 link)
```

---

## Sample Report Output

```
## Executive Summary
Total AWS spend (last 30 days): $4 231.18

Top cost drivers:
- EC2: $1 840 (43%)
- RDS: $920 (22%)
- S3: $410 (10%)

## Finding 1 — 3 Idle EC2 Instances (~$180/month)
Instances i-0abc123, i-0def456, i-0ghi789 averaged < 1% CPU
over the past 14 days. Stop or right-size them.

```hcl
resource "aws_instance" "web" {
  # Change from m5.xlarge → t3.small for dev workloads
  instance_type = "t3.small"
}
```

## Finding 2 — Unattached EBS Volumes (~$94/month)
...
```

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                     AWS Account                     │
│                                                     │
│  EventBridge Scheduler ──► Lambda (Python 3.12)    │
│                              │                      │
│                              ├── Cost Explorer API  │
│                              ├── EC2 / CloudWatch   │
│                              ├── RDS                │
│                              └── Secrets Manager    │
│                                    (Claude API key) │
│                              │                      │
│                              ├── S3 (reports/)      │
│                              └── SNS → Email        │
└─────────────────────────────────────────────────────┘
```

**IAM permissions follow least-privilege:**
- Cost Explorer: `ce:GetCostAndUsage`, `ce:GetRightsizingRecommendation`
- EC2: `ec2:DescribeInstances`, `ec2:DescribeVolumes`, `ec2:DescribeSnapshots` (read-only)
- RDS: `rds:DescribeDBInstances` (read-only)
- CloudWatch: `cloudwatch:GetMetricStatistics` (read-only)
- S3: `s3:PutObject` scoped to the reports bucket
- SNS: `sns:Publish` scoped to the topic ARN
- Secrets Manager: `secretsmanager:GetSecretValue` scoped to the API key secret

---

## Project Structure

```
aws-ai-cost-advisor/
├── src/
│   ├── advisor.py              # Lambda handler (entry point)
│   ├── analyzer.py             # Claude API integration
│   ├── reporter.py             # S3 + SNS publishing
│   └── collectors/
│       ├── cost_explorer.py    # Cost by service, tags, rightsizing
│       ├── ec2.py              # Idle instances, volumes, snapshots
│       └── rds.py              # Idle RDS instances
├── terraform/
│   ├── main.tf                 # Root module
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   └── modules/
│       ├── lambda/             # Function + IAM roles + log group
│       ├── storage/            # S3 bucket + SNS topic
│       └── scheduler/          # EventBridge Scheduler + IAM role
├── .github/workflows/
│   ├── terraform.yml           # Plan on PR, apply on merge (with approval gate)
│   └── deploy.yml              # Build zip → update Lambda code
├── requirements.txt
└── README.md
```

---

## Deployment

### Prerequisites

- AWS account with Cost Explorer enabled
- Anthropic API key
- Terraform ≥ 1.5
- GitHub repository with OIDC configured for AWS

### 1 — Store your Anthropic API key

```bash
# Option A: let Terraform create the secret
# Set anthropic_api_key in terraform.tfvars (see terraform.tfvars.example)

# Option B: use an existing secret
aws secretsmanager create-secret \
  --name aws-ai-cost-advisor/anthropic-api-key \
  --secret-string "sk-ant-..."
```

### 2 — Configure GitHub Secrets

| Secret | Value |
|--------|-------|
| `AWS_DEPLOY_ROLE_ARN` | IAM role ARN with OIDC trust for GitHub Actions |
| `TF_STATE_BUCKET` | S3 bucket for Terraform remote state |
| `TF_LOCK_TABLE` | DynamoDB table for state locking |
| `REPORT_EMAIL` | Email address to receive weekly reports |
| `ANTHROPIC_SECRET_ARN` | ARN of the Secrets Manager secret (if using Option B) |

### 3 — Deploy via Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars

terraform init \
  -backend-config="bucket=YOUR_TFSTATE_BUCKET" \
  -backend-config="key=aws-ai-cost-advisor/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=YOUR_LOCK_TABLE"

terraform plan
terraform apply
```

### 4 — Build & Deploy Lambda Code

```bash
# Build the deployment package locally
pip install -r requirements.txt --target dist/package
cp -r src/* dist/package/
cd dist/package && zip -r ../advisor.zip .

# Deploy
aws lambda update-function-code \
  --function-name aws-ai-cost-advisor-prod \
  --zip-file fileb://dist/advisor.zip
```

Or just push to `main` — GitHub Actions handles it automatically.

### 5 — Manual Test Run

```bash
aws lambda invoke \
  --function-name aws-ai-cost-advisor-prod \
  --payload '{}' \
  --cli-binary-format raw-in-base64-out \
  response.json

cat response.json
```

---

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `environment` | `prod` | Deployment environment |
| `report_recipients` | — | Email list for SNS subscription |
| `schedule_expression` | `cron(0 8 ? * MON *)` | Every Monday 08:00 UTC |
| `lambda_memory_mb` | `512` | Lambda memory (MB) |
| `lambda_timeout_seconds` | `900` | Lambda timeout (15 min) |
| `report_retention_days` | `90` | Days before S3 reports move to Glacier |
| `anthropic_api_key` | — | API key (creates Secrets Manager secret) |
| `anthropic_api_key_secret_arn` | `null` | Existing secret ARN (skips key creation) |

---

## CI/CD

**On Pull Request** → `terraform plan` runs and posts the diff as a PR comment.

**On merge to `main`** → Two jobs run sequentially:
1. `terraform apply` (requires **production** environment approval in GitHub)
2. Lambda code build + deploy (requires **production** environment approval)

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| AI Model | Claude Opus 4.6 (adaptive thinking + streaming) |
| Runtime | Python 3.12 on AWS Lambda |
| Scheduler | EventBridge Scheduler |
| Storage | S3 (reports), Secrets Manager (API key) |
| Notifications | SNS → Email |
| IaC | Terraform ≥ 1.5 |
| CI/CD | GitHub Actions + OIDC |
