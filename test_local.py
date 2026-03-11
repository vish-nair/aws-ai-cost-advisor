"""Quick local smoke test — no AWS credentials needed."""
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "src"))

from analyzer import analyze

fake_inventory = {
    "cost_by_service": {
        "Amazon EC2": 1840.50,
        "Amazon RDS": 920.00,
        "Amazon S3": 410.20,
        "AWS Lambda": 12.40,
        "Amazon CloudWatch": 55.00,
    },
    "cost_by_environment_tag": {
        "prod": 2800.00,
        "staging": 350.00,
        "untagged": 288.10,
    },
    "rightsizing_recommendations": [
        {
            "instance_id": "i-0abc1234567890abc",
            "name": "web-server-01",
            "current_type": "m5.xlarge",
            "recommended_type": "t3.medium",
            "estimated_monthly_savings": 95.20,
        },
        {
            "instance_id": "i-0def1234567890def",
            "name": "analytics-worker",
            "current_type": "c5.2xlarge",
            "recommended_type": "c5.large",
            "estimated_monthly_savings": 142.80,
        },
    ],
    "idle_ec2_instances": [
        {
            "instance_id": "i-0abc1234567890abc",
            "name": "web-server-01",
            "type": "m5.xlarge",
            "avg_cpu": 0.4,
        },
        {
            "instance_id": "i-0ghi1234567890ghi",
            "name": "old-bastion",
            "type": "t3.small",
            "avg_cpu": 0.0,
        },
    ],
    "unattached_ebs_volumes": [
        {
            "volume_id": "vol-0aaa111bbb222ccc3",
            "name": "unnamed",
            "size_gb": 200,
            "type": "gp2",
            "created": "2024-01-15",
        },
        {
            "volume_id": "vol-0ddd444eee555fff6",
            "name": "old-data-backup",
            "size_gb": 500,
            "type": "gp2",
            "created": "2023-11-01",
        },
    ],
    "old_snapshots": [
        {
            "snapshot_id": "snap-0aaa111222333bbb",
            "size_gb": 200,
            "created": "2023-06-01",
            "description": "manual backup before migration",
        },
        {
            "snapshot_id": "snap-0ccc444555666ddd",
            "size_gb": 100,
            "created": "2023-03-15",
            "description": "",
        },
    ],
    "idle_rds_instances": [
        {
            "identifier": "dev-postgres-01",
            "class": "db.t3.medium",
            "engine": "postgres",
            "multi_az": False,
            "avg_connections": 0.0,
        },
    ],
}

print("Sending to Claude for analysis (streaming)...\n")
print("=" * 70)
report = analyze(fake_inventory)
print("\n" + "=" * 70)
print(f"\nDone. Report length: {len(report)} characters.")
