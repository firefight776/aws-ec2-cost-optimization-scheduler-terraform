import boto3
import os

ec2 = boto3.client("ec2")
sns = boto3.client("sns")

TAG_KEY_1 = os.environ.get("TAG_KEY_1", "AutoSchedule")
TAG_VALUE_1 = os.environ.get("TAG_VALUE_1", "true")
TAG_KEY_2 = os.environ.get("TAG_KEY_2", "Environment")
TAG_VALUE_2 = os.environ.get("TAG_VALUE_2", "dev")
SNS_TOPIC_ARN = os.environ.get("SNS_TOPIC_ARN")


def send_notification(subject, message):
    if SNS_TOPIC_ARN:
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )


def get_matching_instances():
    response = ec2.describe_instances(
        Filters=[
            {"Name": f"tag:{TAG_KEY_1}", "Values": [TAG_VALUE_1]},
            {"Name": f"tag:{TAG_KEY_2}", "Values": [TAG_VALUE_2]},
            {"Name": "instance-state-name", "Values": ["running", "stopped"]},
        ]
    )

    instance_ids = []

    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            instance_ids.append(instance["InstanceId"])

    return instance_ids


def lambda_handler(event, context):
    action = event.get("action")
    instance_ids = get_matching_instances()

    print(f"Requested action: {action}")
    print(f"Matching instances: {instance_ids}")

    try:
        if not instance_ids:
            message = "No matching instances found."
            send_notification(
                subject=f"EC2 Scheduler: {action} completed",
                message=message
            )
            return {
                "statusCode": 200,
                "body": message
            }

        if action == "stop":
            response = ec2.stop_instances(InstanceIds=instance_ids)
            print(f"Stop response: {response}")
            message = f"Stopped instances: {instance_ids}"
            send_notification(
                subject="EC2 Scheduler: stop success",
                message=message
            )
            return {
                "statusCode": 200,
                "body": message
            }

        elif action == "start":
            response = ec2.start_instances(InstanceIds=instance_ids)
            print(f"Start response: {response}")
            message = f"Started instances: {instance_ids}"
            send_notification(
                subject="EC2 Scheduler: start success",
                message=message
            )
            return {
                "statusCode": 200,
                "body": message
            }

        else:
            message = "Invalid action. Use 'start' or 'stop'."
            send_notification(
                subject="EC2 Scheduler: invalid action",
                message=message
            )
            return {
                "statusCode": 400,
                "body": message
            }

    except Exception as e:
        error_message = f"Scheduler failed. Action: {action}. Error: {str(e)}"
        print(error_message)
        send_notification(
            subject="EC2 Scheduler: failure",
            message=error_message
        )
        raise