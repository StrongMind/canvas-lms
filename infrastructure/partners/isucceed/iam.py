from pulumi_aws import iam
import json



def create_iam_role_with_policy(name,assume_role_policy,role_policy,tags):
    role = iam.Role(
        f"{name}-role",
        name=f"{name}-role",
        assume_role_policy=json.dumps(assume_role_policy),
        tags=tags,
    )

    iam.RolePolicy(
        f"{name}-policy",
        role=role.id,
        policy=json.dumps(role_policy)
    )
    return role