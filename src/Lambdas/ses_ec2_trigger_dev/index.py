import os
import json
import boto3
from datetime import datetime

ssm        = boto3.client("ssm")
ec2_client = boto3.client("ec2")

def log(event_name, **kwargs):
    print(json.dumps({"event": event_name, "timestamp": datetime.utcnow().isoformat(), **kwargs}))

def handler(event, context):
    instance_name = os.environ.get("EC2_INSTANCE_NAME", "nielsen-playwright-dev")
    report_name   = event.get("report_name", os.environ.get("BYZZER_REPORT", ""))

    log("triggered", instance_name=instance_name, report_name=report_name)

    if not report_name:
        log("error", reason="report_name is missing")
        return {"status": "skipped", "reason": "report_name_missing"}

    # ── Get EC2 instance ID ──────────────────────────────────────────────────
    try:
        response  = ec2_client.describe_instances(
            Filters=[
                {"Name": "tag:Name",            "Values": [instance_name]},
                {"Name": "instance-state-name", "Values": ["running"]}
            ]
        )
        instances = response["Reservations"]

        if not instances:
            log("ec2_not_found", instance_name=instance_name)
            return {"status": "skipped", "reason": "ec2_not_found"}

        instance_id = instances[0]["Instances"][0]["InstanceId"]
        log("ec2_found", instance_id=instance_id, instance_name=instance_name)

    except Exception as e:
        log("ec2_describe_error", error=str(e))
        raise

    # ── Trigger script via SSM ───────────────────────────────────────────────
    try:
        response = ssm.send_command(
            InstanceIds  = [instance_id],
            DocumentName = "AWS-RunShellScript",
            Parameters   = {
                "commands": [
                    "source /etc/environment",          # ← add this
                    "set -a && source /etc/environment && set +a",  # more reliable
                    "export PLAYWRIGHT_BROWSERS_PATH=/home/ec2-user/.playwright",
                    "python3.12 /home/ec2-user/scripts/index.py"
                ]
            },
            Comment = f"Triggered by SES email - report: {report_name}"
        )

        command_id = response["Command"]["CommandId"]
        log("ec2_triggered",
            instance_id=instance_id,
            command_id=command_id,
            report_name=report_name)

        return {
            "status":      "triggered",
            "instance_id": instance_id,
            "command_id":  command_id,
            "report_name": report_name
        }

    except Exception as e:
        log("ssm_error", error=str(e))
        raise