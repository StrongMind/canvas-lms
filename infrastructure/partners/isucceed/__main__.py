"""An AWS Python Pulumi program"""

import pulumi
import pulumi_aws
from pulumi_aws import s3


# Create an AWS resource (S3 Bucket)
bucket = s3.Bucket('my-bucket')

# Export the name of the bucket
pulumi.export('bucket_name', bucket.id)

# Import shared resources from canvas-lms/canvas-lms
# parent_stack = pulumi.StackReference(f'strongmind-devops/canvas-lms/canvas-lms')
# cache_object = parent_stack.get_output('default_redis')

redis_cluster = pulumi_aws.elasticache.Cluster("redis-cluster",
    availability_zone="us-west-2c",
    az_mode="single-az",
    cluster_id="canvas-lms-redis",
    engine="redis",
    engine_version="6.2",
    ip_discovery="ipv4",
    log_delivery_configurations=[pulumi_aws.elasticache.ClusterLogDeliveryConfigurationArgs(
        destination="/aws/redis/canvas-lms-redis",
        destination_type="cloudwatch-logs",
        log_format="json",
        log_type="slow-log",
    )],
    maintenance_window="sun:05:00-sun:09:00",
    network_type="ipv4",
    node_type="cache.t4g.small",
    num_cache_nodes=1,
    parameter_group_name="default.redis6.x",
    port=6379,
    security_group_ids=["sg-0784eb9b3747f42e0"],
    snapshot_window="10:30-11:30",
    subnet_group_name="canvas-lms-redis-subnetgroup",
    tags={
        "environment": "stage",
        "owner": "devops",
        "product": "canvas-lms",
        "service": "canvas-lms",
    },
    opts=pulumi.ResourceOptions(protect=True))

rds = pulumi_aws.rds.Cluster("rds",
    allocated_storage=1,
    availability_zones=[
        "us-west-2a",
        "us-west-2b",
        "us-west-2c",
    ],
    backup_retention_period=5,
    cluster_identifier="canvas-lms-dev",
    database_name="dev",
    db_cluster_parameter_group_name="default.aurora-postgresql10",
    db_subnet_group_name="canvas-lms-rds-subnetgroup",
    engine="aurora-postgresql",
    engine_mode="serverless",
    engine_version="10.18",
    kms_key_id="arn:aws:kms:us-west-2:448312246740:key/c9b474e2-b796-4d8c-beaf-d7ae91b9e2bd",
    master_username="sm_admin",
    network_type="IPV4",
    port=5432,
    preferred_backup_window="07:00-09:00",
    preferred_maintenance_window="wed:09:46-wed:10:16",
    scaling_configuration=pulumi_aws.rds.ClusterScalingConfigurationArgs(
        max_capacity=384,
        min_capacity=2,
        seconds_until_auto_pause=10000,
        timeout_action="ForceApplyCapacityChange",
    ),
    skip_final_snapshot=True,
    storage_encrypted=True,
    tags={
        "environment": "stage",
        "owner": "devops",
        "product": "canvas-lms",
        "service": "canvas-lms",
    },
    vpc_security_group_ids=["sg-0784eb9b3747f42e0"],
    opts=pulumi.ResourceOptions(protect=True))