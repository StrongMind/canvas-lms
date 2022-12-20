import pulumi
import pulumi_aws as aws

def create_lb(name, subnets, security_group, tags):
    lb_options = {
        "load_balancer_type": "application",
        "subnets": subnets,
        "security_groups": security_group,
        "enable_deletion_protection": False,
        "tags": tags,
        "name": name
    }

    lb = aws.lb.LoadBalancer(
        f"{name}-lb",
        **lb_options
    )

    return lb

# health_dict = {
# "port": 3000,
# "healthy_threshold": 6,
# "unhealthy_threshold": 2,
# "timeout": 60,
# "interval": 120
# }

def create_health_check(port, healthy, unhealthy, timeout, interval, path):
    health_dict = {
        "path": path,
        "port": port,
        "healthy_threshold": healthy,
        "unhealthy_threshold": unhealthy,
        "timeout": timeout,
        "interval": interval,
        "matcher": "200"  # has to be HTTP 200 or fails
    }
    return health_dict

# target_types: instance | ip | lambda | alb
def target_group(name, health_dict, target_type, vpc_id, tags):


    tg_options = {
        "port": 80,
        "protocol": "HTTP",
        "target_type": target_type,
        "vpc_id": vpc_id,
        "health_check": health_dict,
        "tags": tags,
        "name": name
    }

    tg = aws.lb.TargetGroup(
        f"{name}-gateway-target-group",
        **tg_options
    )

    return tg

def lb_listener(name, lb_arn, cert, tg_arn, tags, list_of_dependancies=None):
    default_actions = [aws.lb.ListenerDefaultActionArgs(
        type= "forward",
        target_group_arn= tg_arn
    )]

    listener_options = {
        "load_balancer_arn": lb_arn,
        "port": 443,
        "protocol": "HTTPS",
        "certificate_arn": cert,
        "default_actions": default_actions,
        "tags": tags
    }
    if list_of_dependancies:
        listener_options['opts'] = pulumi.ResourceOptions(depends_on=list_of_dependancies)
    listener = aws.lb.Listener(
        f"{name}-listener",
        **listener_options
    )

    return listener