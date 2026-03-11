"""
AWS AI Cost Advisor — Lambda Handler

Triggered weekly by EventBridge Scheduler. Collects AWS cost and resource
utilization data, sends it to Claude for analysis, and publishes a report
with prioritized optimization recommendations and Terraform snippets.
"""
import json
import os

import boto3

from collectors.cost_explorer import get_cost_by_service, get_cost_by_tag, get_savings_recommendations
from collectors.ec2 import get_idle_instances, get_unattached_ebs_volumes, get_old_snapshots
from collectors.rds import get_idle_rds_instances
from analyzer import analyze
from reporter import save_to_s3, publish_to_sns


def _load_anthropic_api_key() -> None:
    """Fetch Claude API key from Secrets Manager and set as env var."""
    secret_arn = os.environ.get("ANTHROPIC_API_KEY_SECRET_ARN")
    if not secret_arn:
        return  # Fall through to ANTHROPIC_API_KEY env var if set directly

    sm = boto3.client("secretsmanager")
    response = sm.get_secret_value(SecretId=secret_arn)
    os.environ["ANTHROPIC_API_KEY"] = response["SecretString"]


def handler(event: dict, context) -> dict:
    print("AWS AI Cost Advisor starting...")
    _load_anthropic_api_key()

    # ── Collect ──────────────────────────────────────────────────────────────
    print("Collecting cost data...")
    inventory = {
        "cost_by_service": get_cost_by_service(days=30),
        "cost_by_environment_tag": get_cost_by_tag(tag_key="Environment", days=30),
        "rightsizing_recommendations": get_savings_recommendations(),
        "idle_ec2_instances": get_idle_instances(),
        "unattached_ebs_volumes": get_unattached_ebs_volumes(),
        "old_snapshots": get_old_snapshots(days=90),
        "idle_rds_instances": get_idle_rds_instances(),
    }

    print(f"Inventory collected: {json.dumps({k: len(v) if isinstance(v, list) else v for k, v in inventory.items()}, indent=2)}")

    # ── Analyze ──────────────────────────────────────────────────────────────
    print("Sending to Claude for analysis...")
    report = analyze(inventory)

    # ── Report ───────────────────────────────────────────────────────────────
    s3_uri = save_to_s3(report, inventory)
    print(f"Report saved to {s3_uri}")

    publish_to_sns(report, s3_uri)
    print("SNS notification sent.")

    return {"statusCode": 200, "body": json.dumps({"report_uri": s3_uri})}
