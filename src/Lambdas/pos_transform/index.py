import os
import json
import boto3
from datetime import datetime
from urllib.parse import unquote_plus

s3 = boto3.client("s3")

def log(event_name, **kwargs):
    print(json.dumps({"event": event_name, "timestamp": datetime.utcnow().isoformat(), **kwargs}))

def handler(event, context):
    for record in event["Records"]:
        bucket   = record["s3"]["bucket"]["name"]
        key    = record["s3"]["object"]["key"]
        key = unquote_plus(key)
        filename = key.split("/")[-1]

        # Extract source and timestamp from key: pos-files/{source}/{timestamp}/{filename}
        parts     = key.split("/")
        source    = parts[1] if len(parts) >= 3 else "unknown"
        timestamp = parts[2] if len(parts) >= 4 else datetime.utcnow().strftime("%Y-%m-%dT%H-%M-%S")

        TRANSFORMED_BUCKET = os.environ.get("TRANSFORMED_BUCKET")

        if not TRANSFORMED_BUCKET:
            log("config_error", reason="TRANSFORMED_BUCKET missing")
            raise ValueError("TRANSFORMED_BUCKET missing")

        try:
            response   = s3.get_object(Bucket=bucket, Key=key)
            body_bytes = response["Body"].read()

            from transform import process_attachment  # ← import here so env vars are loaded first

            output_key = process_attachment(
                s3_client     = s3,
                body_bytes    = body_bytes,
                store_name    = source,
                file_name     = filename,
                timestamp     = timestamp,
                output_bucket = TRANSFORMED_BUCKET
            )

            if output_key:
                log("file_transformed", source=source, filename=filename, output_key=output_key)

        except Exception as e:
            log("transform_error", source=source, filename=filename, error=str(e))
            raise  

    return {"status": "processed"}