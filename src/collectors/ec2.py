import boto3
from datetime import datetime, timedelta


def get_idle_instances() -> list:
    """Find EC2 instances with <5% average CPU over 14 days."""
    ec2 = boto3.client("ec2")
    cw = boto3.client("cloudwatch")
    end = datetime.utcnow()
    start = end - timedelta(days=14)

    paginator = ec2.get_paginator("describe_instances")
    idle = []

    for page in paginator.paginate(Filters=[{"Name": "instance-state-name", "Values": ["running"]}]):
        for reservation in page["Reservations"]:
            for instance in reservation["Instances"]:
                instance_id = instance["InstanceId"]
                instance_type = instance["InstanceType"]
                name = next(
                    (t["Value"] for t in instance.get("Tags", []) if t["Key"] == "Name"),
                    "unnamed",
                )

                metrics = cw.get_metric_statistics(
                    Namespace="AWS/EC2",
                    MetricName="CPUUtilization",
                    Dimensions=[{"Name": "InstanceId", "Value": instance_id}],
                    StartTime=start,
                    EndTime=end,
                    Period=86400,
                    Statistics=["Average"],
                )

                if not metrics["Datapoints"]:
                    idle.append({"instance_id": instance_id, "name": name, "type": instance_type, "avg_cpu": 0.0})
                    continue

                avg_cpu = sum(d["Average"] for d in metrics["Datapoints"]) / len(metrics["Datapoints"])
                if avg_cpu < 5.0:
                    idle.append({"instance_id": instance_id, "name": name, "type": instance_type, "avg_cpu": round(avg_cpu, 2)})

    return idle


def get_unattached_ebs_volumes() -> list:
    """Find EBS volumes not attached to any instance."""
    ec2 = boto3.client("ec2")
    paginator = ec2.get_paginator("describe_volumes")
    volumes = []

    for page in paginator.paginate(Filters=[{"Name": "status", "Values": ["available"]}]):
        for vol in page["Volumes"]:
            name = next((t["Value"] for t in vol.get("Tags", []) if t["Key"] == "Name"), "unnamed")
            volumes.append({
                "volume_id": vol["VolumeId"],
                "name": name,
                "size_gb": vol["Size"],
                "type": vol["VolumeType"],
                "created": str(vol["CreateTime"].date()),
            })

    return volumes


def get_old_snapshots(days: int = 90) -> list:
    """Find EBS snapshots older than N days owned by this account."""
    ec2 = boto3.client("ec2")
    sts = boto3.client("sts")
    account_id = sts.get_caller_identity()["Account"]
    cutoff = datetime.utcnow() - timedelta(days=days)

    response = ec2.describe_snapshots(OwnerIds=[account_id])
    old = []
    for snap in response["Snapshots"]:
        if snap["StartTime"].replace(tzinfo=None) < cutoff:
            old.append({
                "snapshot_id": snap["SnapshotId"],
                "size_gb": snap["VolumeSize"],
                "created": str(snap["StartTime"].date()),
                "description": snap.get("Description", "")[:80],
            })

    return sorted(old, key=lambda x: x["created"])[:20]
