"""An AWS Python Pulumi program"""

import pulumi
import pulumi_aws
import vpc
import rds
import redis
import os
import json
import ecs
import iam
import cloudwatch
###GLOBAL VARIABLES
stack = pulumi.get_stack()
region = pulumi_aws.config.region
config = pulumi.Config()
# Set our Tags which we pass to every object to ensure that it follows
# company set practices
tags = config.require_object("tags")
###END

##REQUIRES: vpc,
# Get our global cidr block for our vpc, which all subnets
# for this application will be a part of.
cidr = config.require("cidr")

# Build our vpc using our cidr and tags, returning its arn information
vpc_object = vpc.vpc(stack, cidr, tags)

# Pull the object array from the yaml containing the security group settings
security_group_config = config.require_object("security_group")

# setup our empty list of security group id's to be passed to our applications.
security_group_ids = list()

# Loop through our security group configuration to build each group and then
# append the output to our list of security group ids
for sec_g in security_group_config:
    security_group_ids.append(vpc.sg(
        stack,
        int(sec_g["from_port"]),
        int(sec_g["to_port"]),
        "tcp",
        "0.0.0.0/0",
        vpc_object.id,
        tags
    ).id)

###START of rds config
##REQUIRES: vpc, rds,
# This should really be pulled from Tags, or Tags should have this added
# in the code as we don't need to declare the same variable twice,
# they should be locked together
environment = config.require("env")

# Pull the postgres settings from our yaml
postgres = config.require_object("postgres")

# Create an empty list to store our subnet_ids
subnet_ids = list()

# Pull our subnet settings from our configuration file.
subnet_dict = config.require_object("subnets")

# Loop through our subnet object to build the subnet objects and
# append their ID's to the subnet id list
for sub in subnet_dict:
    build_subnet = vpc.subnet(
        f"{stack}-{sub['availability_zone']}",
        vpc_object.id,
        sub["cidr_block"],
        sub["availability_zone"],
        tags
    )
    subnet_ids.append(build_subnet.id)

###END of network config

# Build the subnet group for our rds instance so that it
# can attach to our vpc and talk with other services
build_rds_subnet = rds.subnetgroup(
    stack,
    subnet_ids,
    tags
)

# Build the postgres server, handing it our security groups and subnet
# information so that it can talk to other services in our private
# network.
db_env = config.require("env")
postgres_server = rds.build_rds(
    stack,
    security_group_ids,
    tags,
    build_rds_subnet.name,
    postgres,
    db_env
)
###END of rds config

###START of redis
##REQUIRES: vpc, redis,
# These 3 are all only used in the Redis cache cluster, Can we get them
# put into the same object and then nest the metrics under it as well so
# they are all in one large object for redis
redis_config=config.require_object("redis")

node_type = redis_config['node']
auto_minor_version_upgrade = redis_config["auto_minor_version_upgrade"]
maintenance_window = redis_config["maintenance_window"]

# Build the subnet group for our redis instance so that it
# can attach to our vpc and talk with other services
build_redis_subnet = redis.subnetgroup(
    stack,
    subnet_ids,
    tags
)

# Create our cache object for our cluster, needs to have security group ids
# and subnet name sent to it.
cache_object = redis.cluster(
    stack,
    node_type,
    tags,
    auto_minor_version_upgrade,
    maintenance_window,
    security_group_ids=security_group_ids,
    subnet_group=build_redis_subnet.name
    )

metric_dict = redis_config["metrics"]
cachenodeid = cache_object.cache_nodes[0]["id"]
cacheclusterid = cache_object.cluster_id

for metric in metric_dict:
    build_redis_monitoring = redis.monitoring(
        stack,
        tags,
        metric["metric_name"],
        metric["sns_arn"],
        metric["threshold"],
        metric["period"],
        metric["comparison_operator"],
        cachenodeid,
        cacheclusterid
    )

redis_url = cache_object.cache_nodes[0]["address"]
###END of redis config

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
redis_url = cache_object.cache_nodes[0]["address"]



assume_role_policy = config.require_object("assume_role_policy")
role_policy = config.require_object("role_policy")
role = iam.create_iam_role_with_policy(
    stack,
    assume_role_policy,
    role_policy,
    tags
)
ecs_environment_config = config.require_object("ecs")
# Create an internet gateway attached to our vpc
internet_gateway = vpc.create_gateway(stack, vpc_object.id, tags)

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

#     if container['name'] == "web":
#
#         ecs_lb = ecs.set_loadbalancer_args(
#             container_name,
#             port_mapping[0]['containerPort'],
#             target_group.arn
#         )
#     else:
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
