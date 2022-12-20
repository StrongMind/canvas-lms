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
internet_gateway = vpc.create_gateway(stack, vpc_object.id, tags)

# Create a route in the vpc route table to the internet gateway
route = vpc.create_route(
    stack,
    vpc_object.main_route_table_id,
    internet_gateway.id
)

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
# pulumi.log.info("redis:", cache_object)
# pulumi.export("redis", stack.redis)
###END of redis config