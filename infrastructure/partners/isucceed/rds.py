import pulumi
import pulumi_aws as aws
from pulumi_aws import cloudwatch


def subnetgroup(name, subnet_ids, tags):
    subnet = aws.rds.SubnetGroup(
        f"{name}-rds-subnetgroup",
        name=f"{name}-rds-subnetgroup",
        subnet_ids=subnet_ids,
        tags=tags
    )
    return subnet


def build_rds(name, sec_groups, tags, db_subnet_group_name, rds_options_yaml=dict(), env="dev"):
    # configure the rds cluster options
    # start by validating the inputs
    env = env.lower() if env else "dev"
    db_name = env
    clusterid = f"{name}-{env}"

    rds_options = {
        "cluster_identifier": f"{clusterid}",
        "engine": "aurora-postgresql",
        "tags": tags,
        "availability_zones": [
            "us-west-2a",
            "us-west-2b",
            "us-west-2c"
        ],
        "vpc_security_group_ids": sec_groups,
        "database_name": db_name,
        "backup_retention_period": 5,
        "engine_mode": "serverless",
        "scaling_configuration": {
            "auto_pause": True,
            "max_capacity": 384,
            "min_capacity": 4 if env == "prod" else 2,
            "seconds_until_auto_pause": 10000,
            "timeout_action": "ForceApplyCapacityChange"
        },
        "storage_encrypted": True,
        "preferred_backup_window": "07:00-09:00",
        "skip_final_snapshot": True,
        "db_subnet_group_name": db_subnet_group_name
    }

    rds_options = {**rds_options_yaml, **rds_options}
    # call aws to create the cluster
    rds_cluster = aws.rds.Cluster(
        f"{name}-rds-cluster",
        **rds_options
    )

    # Setup Logging in cloudwatch
    cloudwatch.LogGroup(
        f"{name}-rds-log",
        retention_in_days=14,
        name=f"/aws/rds/{name}-rds"
    )
    pulumi.export('rds_url', rds_cluster.endpoint)
    return rds_cluster

    # setup a default alarm in aws


def monitoring(name, tags, database_name, metric_name, sns_arn, threshold, period):
    cloudwatch.MetricAlarm(
        f"{database_name}-{metric_name}",
        name=f"{database_name}-{metric_name}-alarm".lower().replace(' ', '-'),
        metric_name=metric_name,
        period=period,
        namespace='AWS/RDS',
        statistic="Average",
        comparison_operator="GreaterThanThreshold",
        evaluation_periods=1,
        alarm_actions=[sns_arn],
        ok_actions=[sns_arn],
        treat_missing_data="notBreaching",
        datapoints_to_alarm=1,
        threshold=threshold,
        tags=tags
    )
