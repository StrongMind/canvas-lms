import pulumi
from pulumi_aws import ec2

def vpc(
    name,
    cidr_block,
    tags
    ):
    vpc=ec2.Vpc(
    f'{name}-vpc',
    cidr_block=cidr_block,
    tags=tags,
    enable_dns_hostnames=True,
    enable_dns_support=True
    )
    return vpc

def subnet(
    name,
    vpc_id,
    cidr_block,
    availability_zone,
    tags
    ):
    subnet=ec2.Subnet(
    f'{name}-vpc',
    vpc_id=vpc_id,
    cidr_block=cidr_block,
    availability_zone=availability_zone,
    tags=tags,
    opts=pulumi.ResourceOptions(delete_before_replace=True)
    )
    return subnet

#cidr_blocks=[cidr_block] may need to be 0.0.0.0/0
#protocol may need to be https
def sg(
    name,
    from_port,
    to_port,
    protocol,
    cidr_block,
    vpc_id,
    tags
    ):
    sg=ec2.SecurityGroup(
    f'{name}-sg',
    vpc_id=vpc_id,
    ingress=[ec2.SecurityGroupIngressArgs(
        from_port=from_port,
        to_port=to_port,
        protocol=protocol,
        cidr_blocks=[cidr_block]
        )],
    egress=[ec2.SecurityGroupIngressArgs(
        from_port=from_port,
        to_port=to_port,
        protocol=protocol,
        cidr_blocks=[cidr_block]
        )],
    tags=tags,
    )
    return sg

# Create a route in the vpc route table to the internet gateway
def create_route(stack, main_route_table_id,internet_gateway_id ):

    route = ec2.Route(f"{stack}-route",
        route_table_id=main_route_table_id,
        destination_cidr_block="0.0.0.0/0",
        gateway_id=internet_gateway_id
        )

#Create Internet Gateway for VPC, required object if they will be using a load balancer
def create_gateway(name, vpc_id, tags ):
    gateway = ec2.InternetGateway(
        name,
        vpc_id=vpc_id,
        tags=tags
    )
    return gateway

