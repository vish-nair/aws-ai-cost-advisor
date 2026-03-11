import boto3
import json
import os
from datetime import datetime


def save_to_s3(report: str, inventory: dict) -> str:
    """Save the full report and raw inventory to S3. Returns the S3 URI."""
    s3 = boto3.client("s3")
    bucket = os.environ["REPORT_BUCKET"]
    timestamp = datetime.utcnow().strftime("%Y-%m-%d_%H-%M")
    key = f"reports/{timestamp}/report.md"
    raw_key = f"reports/{timestamp}/inventory.json"

    s3.put_object(Bucket=bucket, Key=key, Body=report.encode(), ContentType="text/markdown")
    s3.put_object(Bucket=bucket, Key=raw_key, Body=json.dumps(inventory, indent=2).encode(), ContentType="application/json")

    return f"s3://{bucket}/{key}"


def publish_to_sns(report: str, s3_uri: str) -> None:
    """Publish a summary notification to SNS."""
    sns = boto3.client("sns")
    topic_arn = os.environ["SNS_TOPIC_ARN"]

    # Send first 2000 chars as SNS preview + link to full report in S3
    preview = report[:2000] + f"\n\n---\nFull report: {s3_uri}"

    sns.publish(
        TopicArn=topic_arn,
        Subject=f"AWS Cost Advisor Report — {datetime.utcnow().strftime('%Y-%m-%d')}",
        Message=preview,
    )
