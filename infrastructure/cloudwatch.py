"""An AWS Python Pulumi program"""

import pulumi
from pulumi_aws import cloudwatch

"""
pattern="Powerschool"
error="ConnectionError"
metricname="powerschool-oneroster-adapter-prod-http-handler-lambda PowerSchool"
log_group="/aws/lambda/powerschool-oneroster-adapter-prod-http-handler-lambda"
name_space="Connection Error"
"""

def create_log_group(name,service,suffix):
    return cloudwatch.LogGroup(
        f'{name}-{suffix}-log',
        retention_in_days=14,
        name=f'/aws/{service}/{name}-{suffix}'
    )

def create_log_alert(name, 
                pattern, 
                metricname, 
                log_group, 
                name_space, 
                alarm_object, 
                error=None
                ):
    if error == None:
        error_pattern = f'"{pattern}"'
    else:
        error_pattern = f'"{error}: {pattern}"'

    cloudwatch.LogMetricFilter(
        f"{name}-log-metric",
        pattern=f'{error_pattern}',
        log_group_name=log_group,
        metric_transformation=cloudwatch.LogMetricFilterMetricTransformationArgs(
            name=metricname,
            namespace=name_space,
            value="1"
        ),
        name=f"{name}-log-metric".lower().replace(' ', '-')
    )

    cloudwatch.MetricAlarm(f"{name}-log-metric-alarm",**alarm_object)

def create_metric_alert(
                name, 
                alarm_object
                ):

    cloudwatch.MetricAlarm(
        f"{name}",
        **alarm_object
    )

def alarm_type(pattern):
    if pattern in ("LessThanLowerOrGreaterThanUpperThreshold",
                "GreaterThanUpperThreshold",
                "LessThanLowerThreshold"
    ):
        return anomoly_detection_alarm
    else:
        return static_alarm


def anomoly_detection_alarm(
                        name, 
                        metricname, 
                        arn, 
                        name_space,
                        comparison_operator, 
                        description="If you can read this, my deployment has no description",
                        statistic="Sum",
                        threshold="50",
                        dimensions=None
                        ):
    anomoly_alarm_object = {
        "name":f"{name}-log-metric-alarm".lower().replace(' ', '-'),
        "comparison_operator":comparison_operator,
        "evaluation_periods":1,
        "treat_missing_data":"notBreaching",
        "alarm_description":description,
        "alarm_actions":[arn],
        "ok_actions":[arn],
        "threshold_metric_id":"ad1",
        "metric_queries" :[
            cloudwatch.MetricAlarmMetricQueryArgs(
                id="m1",
                return_data=True,
                metric=cloudwatch.MetricAlarmMetricQueryMetricArgs(
                    metric_name=metricname,
                    period=60,
                    stat=statistic,
                    namespace=name_space
                )
            ),
            cloudwatch.MetricAlarmMetricQueryArgs(
                id="ad1",
                label=f"{metricname} anomoly",
                return_data=True,
                expression=f"ANOMALY_DETECTION_BAND(m1, {threshold})"
            )
        ]
    }
    return anomoly_alarm_object

def static_alarm(
            name,
            metricname,
            arn,
            name_space,
            comparison_operator,
            description,
            statistic,
            threshold,
            dimensions=None
    ):
    static_alarm_object = {
        "name":f"{name}".lower().replace(' ', '-'),
        "comparison_operator":comparison_operator,
        "evaluation_periods":1,
        "treat_missing_data":"notBreaching",
        "alarm_description":description,
        "alarm_actions":[arn],
        "ok_actions":[arn],
        "threshold":threshold,
        "metric_name":metricname,
        "period":60,
        "statistic":statistic,
        "namespace":name_space,
        "dimensions":dimensions,
        "datapoints_to_alarm":1
    }
    return static_alarm_object




def create_eventbus(stack,tags):
    return cloudwatch.EventBus(
        f"{stack}-eventbus",
        name=f"{stack}-eventbus",
        tags=tags
    )

def create_eventrule(
    stack,
    is_enabled,
    schedule_expression,
    tags
    ):
    return cloudwatch.EventRule(
        f"{stack}-eventrule",
        is_enabled=is_enabled,
        schedule_expression=schedule_expression,
        tags=tags
    )

def create_event_target(
    stack,
    queue_arn,
    schedule_name,
    job_definition,
    job_name,
    role_arn
    ):
    return cloudwatch.EventTarget(
        f"{stack}-event-target",
        arn=queue_arn,
        rule=schedule_name,
        batch_target=cloudwatch.EventTargetBatchTargetArgs(
                job_definition=job_definition,
                job_name=job_name,
                job_attempts=1
                ),
        role_arn=role_arn
        )

