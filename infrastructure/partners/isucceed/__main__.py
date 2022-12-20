"""An AWS Python Pulumi program"""

import pulumi
import pulumi_aws
from pulumi_aws import s3
import cloudwatch
import iam
import ecs
import vpc
import json

# Create an AWS resource (S3 Bucket)
bucket = s3.Bucket('my-bucket')

###GLOBAL VARIABLES
stack = pulumi.get_stack()
region = pulumi_aws.config.region
config = pulumi.Config()

vpc_object = pulumi_aws.ec2.Vpc.get('canvas-lms-vpc', 'vpc-037040915e17ff9af')
internet_gateway = pulumi_aws.ec2.InternetGateway.get('canvas-lms', 'igw-0689144945674f784')
environment = config.require("env")
tags = config.require_object("tags")

# Import shared resources from canvas-lms/canvas-lms
parent_stack = pulumi.StackReference(f'strongmind-devops/canvas-lms/canvas-lms')

subnet_ids = parent_stack.get_output('subnet_ids')
pulumi.export("subnet_ids", subnet_ids)

security_group_ids = parent_stack.get_output('security_group_ids')
# pulumi.log.info("subnet_ids", subnet_ids)

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

postgres_server = pulumi_aws.rds.Cluster("rds",
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

    ###START of ECS config
##REQIRES: cloudwatch, redis, iam, ecs, lb,
aws_cloudwatch_log_group = cloudwatch.create_log_group(stack, "ecs", "ecs")



"""
ALRIGHT FOLKS, I HATE WHAT IM ABOUT TO DO, DONT @ ME
"""
"""
Output.concat is 0 indexed, so add 1 to any sequence it gives you.
"""
# LOG_CONFIG_OUTPUT = ""
LOG_CONFIG_OUTPUT = pulumi.Output.concat(
    '{"logDriver": "awslogs","options": {"awslogs-group":"',
    aws_cloudwatch_log_group.id,
    '","awslogs-region":"',
    region,
    '","awslogs-stream-prefix": "ecs"}}'
)
redis_url = redis_cluster.cache_nodes[0]["address"]



assume_role_policy = config.require_object("assume_role_policy")
role_policy = config.require_object("role_policy")
role = iam.create_iam_role_with_policy(
    stack,
    assume_role_policy,
    role_policy,
    tags
)
ecs_environment_config = config.require_object("ecs")

# Pull the postgres settings from our yaml
postgres = config.require_object("postgres")

# Create a route in the vpc route table to the internet gateway
route = vpc.create_route(
    stack,
    vpc_object.main_route_table_id,
    internet_gateway.id
)

for container in ecs_environment_config:
    container_name = f"{stack}-{container['name']}"
    # On a time crunch, but we lose information this way ( I.E. We are blindly overwriting the same variable,
    # with itself plus additional data, hard to tell where the json object may get corrupted.
    ENVIRONMENT_VAR_OUTPUT = pulumi.Output.concat(
        '[{"name":"RAILS_ENV","value":"', environment, '"}',
        ',{"name":"DATABASE_USERNAME","value":"', postgres['master_username'], '"}',
        ',{"name":"DATABASE_PASSWORD","value":"', postgres['master_password'], '"}',
        ',{"name":"DATABASE_NAME","value":"', postgres_server.database_name, '"}',
        ',{"name":"DATABASE_HOST","value":"', postgres_server.endpoint, '"}'
    )

#     for env_key, env_val in container['environment'].items():
#         ENVIRONMENT_VAR_OUTPUT = pulumi.Output.concat(
#             ENVIRONMENT_VAR_OUTPUT,
#             ',{"name":"', env_key, '","value":"', env_val, '"}'
#         )

    ENVIRONMENT_VAR_OUTPUT = pulumi.Output.concat(
        ENVIRONMENT_VAR_OUTPUT,
        ',{"name":"REDIS_URL","value":"redis://', redis_url, ':6379"}]'
    )

    memory = container['memory']
    cpu = container["cpu"]
    entry_point = container["entryPoint"]
    port_mapping = container["port_mapping"]

    image_dict = container["image"]
    our_image = f"{image_dict}:latest"

    Our_json_output = pulumi.Output.concat(
        '[{"name":"', container_name,'"',
        ',"image":"', our_image, '"',
        ',"memory":', memory,
        ',"cpu":', cpu,
        ',"logConfiguration":', LOG_CONFIG_OUTPUT,
        ',"entryPoint":', json.dumps(entry_point),
        ',"essential": true, "portMappings":[',
        '{"containerPort":', str(port_mapping[0]['containerPort']),
        ',"hostPort":', str(port_mapping[0]['hostPort']),'}',
        '],"environment":', ENVIRONMENT_VAR_OUTPUT,'}]'
    )

    ecs_lb = None
    ecs_network = ecs.set_network_configuration(
        subnet_ids,
        security_group_ids,
        public_ip=True
    )
    ecs_object = ecs.create_task_definition(
        container_name,
        Our_json_output,
        role.arn,
        memory,
        cpu
    )

    cluster = ecs.create_cluster(container_name)
    ecs.create_ecs_service(
        container_name,
        cluster,
        ecs_object,
        2,
        ecs_network,
        ecs_lb,
        tags
    )


# ecs.create_endpoints(stack, vpc_object, subnet_ids, security_group_ids)

###END of ECS config