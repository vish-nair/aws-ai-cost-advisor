import boto3
from datetime import datetime, timedelta


def get_idle_rds_instances() -> list:
    """Find RDS instances with near-zero connections over 14 days."""
    rds = boto3.client("rds")
    cw = boto3.client("cloudwatch")
    end = datetime.utcnow()
    start = end - timedelta(days=14)

    response = rds.describe_db_instances()
    idle = []

    for db in response["DBInstances"]:
        identifier = db["DBInstanceIdentifier"]
        db_class = db["DBInstanceClass"]
        engine = db["Engine"]
        multi_az = db["MultiAZ"]

        metrics = cw.get_metric_statistics(
            Namespace="AWS/RDS",
            MetricName="DatabaseConnections",
            Dimensions=[{"Name": "DBInstanceIdentifier", "Value": identifier}],
            StartTime=start,
            EndTime=end,
            Period=86400,
            Statistics=["Average"],
        )

        if not metrics["Datapoints"]:
            avg_connections = 0.0
        else:
            avg_connections = sum(d["Average"] for d in metrics["Datapoints"]) / len(metrics["Datapoints"])

        if avg_connections < 1.0:
            idle.append({
                "identifier": identifier,
                "class": db_class,
                "engine": engine,
                "multi_az": multi_az,
                "avg_connections": round(avg_connections, 2),
            })

    return idle
