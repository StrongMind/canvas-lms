from pulumi_aws import ecs, ec2
import json
import pulumi
"""resource "aws_ecs_task_definition" "web_app" {

  family                   = "web_app"
  requires_compatibilities = ["FARGATE"]             # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"                # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
  cpu                      = 256
  task_role_arn            = aws_iam_role.ecs_execution_role.arn
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  container_definitions    = jsonencode("""


"""          "image" : "${data.aws_ecr_repository.ecr_repo.repository_url}:${data.external.git_ref.result.commit}",
          "entryPoint" : ["sh", "-c", "rails db:prepare db:migrate && rails server --port 3000 -b 0.0.0.0"],"""


def create_task_definition(name,container_definitions, role_arn , memory, cpu):
    pulumi.log.info(f"{container_definitions}")
    task = ecs.TaskDefinition(
        f"{name}-task-definition",
        family=name,
        container_definitions=container_definitions,
        task_role_arn=role_arn,
        execution_role_arn=role_arn,
        requires_compatibilities=["FARGATE"],
        memory=memory,
        cpu=cpu,
        network_mode="awsvpc"
    )
    return task

def set_loadbalancer_args(
    container_name,
    container_port,
    target_group_arn
):
    return [ecs.ServiceLoadBalancerArgs(
        container_name=container_name,
        container_port=container_port,
        target_group_arn=target_group_arn
    )]

    pass

def set_network_configuration(
    subnets,
    security_groups,
    public_ip=False
    ):
    return ecs.ServiceNetworkConfigurationArgs(
        subnets=subnets,
        assign_public_ip=public_ip,
        security_groups=security_groups
    )



def create_cluster(name,tags=None):
    cluster = ecs.Cluster(
        f"{name}-cluster",
        name=name,
        tags=tags
    )
    return cluster

def create_ecs_service(name, cluster,task_definition, desired_count, network_configuration, load_balancer, tags, health_check_grace_period=False):

    service_object = {
        "cluster" : cluster.id,
        "task_definition" : task_definition,
        "desired_count" : desired_count,
        "launch_type" : "FARGATE",
        "platform_version" : "1.4.0",
        "network_configuration" : network_configuration,
        "load_balancers" : load_balancer,
        "tags": tags

    }
    if health_check_grace_period:
        service_object["health_check_grace_period_seconds"] = health_check_grace_period

    service = ecs.Service(
        f"{name}-service",
        **service_object
    )
    return service


def create_endpoints(name, vpc_object, subnet_ids, security_group_ids):
    # Collect the endpoints in a list incase we need it later
    end_points = {'ecr-dkr': 'com.amazonaws.us-west-2.ecr.dkr',
                  'ecr-logs': 'com.amazonaws.us-west-2.logs',
                  'ecr-api': 'com.amazonaws.us-west-2.ecr.api',
                  'ecs': 'com.amazonaws.us-west-2.ecs',
                  'ecs-agent': 'com.amazonaws.us-west-2.ecs-agent',
                  'ecs-telemetry': 'com.amazonaws.us-west-2.ecs-telemetry',
                  'ecs-monitoring': 'com.amazonaws.us-west-2.monitoring',
                  'ecs-secret':'com.amazonaws.us-west-2.secretsmanager'
                  }

    gateways = {'ecr-s3': 'com.amazonaws.us-west-2.s3'}

    for end_point_name, end_point in end_points.items():
        ec2.VpcEndpoint(
            f"{name}-{end_point_name}",
            vpc_id=vpc_object.id,
            service_name=end_point,
            private_dns_enabled=True,
            subnet_ids=subnet_ids,
            security_group_ids=security_group_ids,
            vpc_endpoint_type="Interface"
            )

    for end_point_name, end_point in gateways.items():
        ec2.VpcEndpoint(
            f"{name}-{end_point_name}",
            vpc_id=vpc_object.id,
            service_name=end_point,
            route_table_ids=[vpc_object.main_route_table_id],
            vpc_endpoint_type="Gateway"
            )
