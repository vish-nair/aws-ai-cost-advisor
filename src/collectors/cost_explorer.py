import boto3
from datetime import datetime, timedelta


def get_cost_by_service(days: int = 30) -> dict:
    """Fetch AWS cost grouped by service for the last N days."""
    client = boto3.client("ce")
    end = datetime.utcnow().date()
    start = end - timedelta(days=days)

    response = client.get_cost_and_usage(
        TimePeriod={"Start": str(start), "End": str(end)},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
    )

    results = []
    for period in response["ResultsByTime"]:
        for group in period["Groups"]:
            service = group["Keys"][0]
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            if amount > 0.01:
                results.append({"service": service, "cost_usd": round(amount, 2)})

    results.sort(key=lambda x: x["cost_usd"], reverse=True)
    return {"period_days": days, "services": results[:20]}


def get_cost_by_tag(tag_key: str = "Environment", days: int = 30) -> dict:
    """Fetch cost grouped by a specific tag to spot untagged resources."""
    client = boto3.client("ce")
    end = datetime.utcnow().date()
    start = end - timedelta(days=days)

    response = client.get_cost_and_usage(
        TimePeriod={"Start": str(start), "End": str(end)},
        Granularity="MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "TAG", "Key": tag_key}],
    )

    tagged = 0.0
    untagged = 0.0
    for period in response["ResultsByTime"]:
        for group in period["Groups"]:
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            label = group["Keys"][0]
            if label in ("", f"{tag_key}$"):
                untagged += amount
            else:
                tagged += amount

    return {
        "tag_key": tag_key,
        "tagged_usd": round(tagged, 2),
        "untagged_usd": round(untagged, 2),
    }


def get_savings_recommendations() -> list:
    """Pull Cost Explorer right-sizing recommendations."""
    client = boto3.client("ce")
    try:
        response = client.get_rightsizing_recommendation(
            Service="AmazonEC2",
            Configuration={"RecommendationTarget": "SAME_INSTANCE_FAMILY", "BenefitsConsidered": True},
        )
        recs = []
        for r in response.get("RightsizingRecommendations", [])[:10]:
            detail = r.get("ModifyRecommendationDetail", {})
            recs.append({
                "instance_id": r["CurrentInstance"]["ResourceId"],
                "current_type": r["CurrentInstance"]["ResourceDetails"]["EC2ResourceDetails"]["InstanceType"],
                "recommended_type": detail.get("TargetInstances", [{}])[0]
                .get("ResourceDetails", {})
                .get("EC2ResourceDetails", {})
                .get("InstanceType", "N/A"),
                "estimated_monthly_savings": detail.get("TargetInstances", [{}])[0]
                .get("EstimatedMonthlySavings", "N/A"),
            })
        return recs
    except Exception:
        return []
