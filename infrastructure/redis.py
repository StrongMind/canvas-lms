import pulumi
from pulumi_aws import elasticache, cloudwatch

def cluster(
    name,
    node_type,
    tags,
    auto_minor_version_upgrade,
    maintenance_window,
    security_group_ids=None,
    subnet_group=None,
    parameter_group_name="default.redis6.x"
    ):
    cloudwatch.LogGroup(
        f'{name}-redis-log',
        retention_in_days=14,
        name=f'/aws/redis/{name}-redis'
    )
    elastic=elasticache.Cluster(
        f'{name}-redis-cluster',
        engine="redis",
        engine_version="6.x",
        node_type=node_type,
        num_cache_nodes=1,
        parameter_group_name=parameter_group_name,
        port=6379,
        tags=tags,
        auto_minor_version_upgrade=auto_minor_version_upgrade,
        maintenance_window=maintenance_window,
        security_group_ids=security_group_ids,
        subnet_group_name=subnet_group,
        apply_immediately=True,
        cluster_id=f'{name}-redis',
        log_delivery_configurations=[
            elasticache.ClusterLogDeliveryConfigurationArgs(
                destination=f'/aws/redis/{name}-redis',
                destination_type="cloudwatch-logs",
                log_format="json",
                log_type="slow-log"
                )
        ]
    )

    return elastic

def monitoring(
    name,
    tags,
    metric_name,
    sns_arn,
    threshold,
    period,
    comparison_operator,
    cachenodeid,
    cacheclusterid
    ):
    cloudwatch.MetricAlarm(
        f"{name}-{metric_name}",
        name=f"{name}-{metric_name}-alarm".lower().replace(' ', '-'),
        metric_name=metric_name,
        comparison_operator=comparison_operator,
        evaluation_periods=1,
        statistic="Average",
        namespace="AWS/ElastiCache",
        period=period,
        alarm_actions=[sns_arn],
        dimensions={
            "CacheClusterId":cacheclusterid,
            "CacheNodeId":cachenodeid
        },
        ok_actions=[sns_arn],
        treat_missing_data="notBreaching",
        datapoints_to_alarm=1,
        threshold=threshold,
        tags=tags
    )

def subnetgroup(
    name,
    subnet_ids,
    tags
    ):
    subnet = elasticache.SubnetGroup(
        f"{name}-redis-subnetgroup",
        name=f"{name}-redis-subnetgroup",
        subnet_ids=subnet_ids,
        tags=tags
    )
    return subnet