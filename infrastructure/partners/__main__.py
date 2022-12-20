"""An AWS Python Pulumi program"""

import pulumi
from pulumi_aws import s3
import os
import json
import ecs
###GLOBAL VARIABLES
stack = pulumi.get_stack()
region = pulumi_aws.config.region
config = pulumi.Config()
# Set our Tags which we pass to every object to ensure that it follows
# company set practices
tags = config.require_object("tags")
###END

# Create an AWS resource (S3 Bucket)
bucket = s3.Bucket('my-bucket')

# Export the name of the bucket
pulumi.export('bucket_name', bucket.id)

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

###START of load balancer config
##REQUIRES: vpc, route53, certs,lb,
#Create the load balancer
loadBalancer = lb.create_lb(
    stack,
    subnet_ids,
    security_group_ids,
    tags
)

dns = config.require_object("dns")
# Test using LB to create the CNAMES
web_route = route53.build_lb_route53(
    stack,
    dns['lb_name'],
    dns['zone_id'],
    loadBalancer
)
# Retrive any health_check from the yaml file.
health_check_yaml = config.require_object("healthcheck")

health_check = lb.create_health_check(
    health_check_yaml['port'],
    health_check_yaml['healthy_threshold'],
    health_check_yaml['unhealthy_threshold'],
    health_check_yaml['timeout'],
    health_check_yaml['interval'],
    health_check_yaml['path'],
)
# create target group
# def target_group(name, health_dict, target_type, vpc_id, tags):
target_group = lb.target_group(
    stack,
    health_check,
    'ip',
    vpc_object.id,
    tags
)

#Configure certificate for load balancer listener
certificates = config.require_object("certificates")
cert = certs.build_cert(
    f"{stack}-{certificates[0]['domain']}",
    zone=dns["zone_name"],
    domain=certificates[0]["domain"],
    zone_id=dns["zone_id"],
    tags=tags
)
# add listener
# def lb_listener(name, lb_arn, cert_arn, tg_arn, tags):
lb_listener = lb.lb_listener(
    stack,
    loadBalancer.arn,
    cert.arn,
    target_group.arn,
    tags,
    list_of_dependancies=[cert]
)
###END of load balancer config
