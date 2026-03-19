import os
import json
import base64
import boto3
from email import policy
from email.parser import BytesParser
from datetime import datetime

from transform import process_attachment

s3 = boto3.client("s3")

def log(event_name, **kwargs):
    print(json.dumps({"event": event_name, "timestamp": datetime.utcnow().isoformat(), **kwargs}))

def norm(s):
    return s.lower() if isinstance(s, str) else ""

def score_vendor(cfg, from_addr, reply_to, subject, body, attachments):
    score = 0
    keywords = cfg.get("keywords", [])

    for k in keywords:
        if k in from_addr: score += 1
        if k in reply_to: score += 1
        if k in subject:  score += 1
        if k in body:     score += 1

    if cfg.get("subject_filter") and any(f in subject for f in cfg["subject_filter"]):
        score += 1

    for att in attachments:
        for k in keywords:
            if k in att["filename"].lower():
                score += 1

    return score


def handler(event, context):
    RAW_BUCKET        = os.environ.get("RAW_BUCKET_EMAIL")
    TRANSFORMED_BUCKET = os.environ.get("TRANSFORMED_BUCKET")
    vendor_config = json.loads(os.environ.get("VENDOR_CONFIG", "{}"))

    if not RAW_BUCKET:
        log("config_error", reason="RAW_BUCKET_EMAIL environment variable is missing")
        raise ValueError("RAW_BUCKET_EMAIL environment variable is missing")

    if not vendor_config:
        log("config_error", reason="VENDOR_CONFIG is missing or empty")
        raise ValueError("VENDOR_CONFIG is missing or empty")

    record     = event["Records"][0]["ses"]
    mail       = record["mail"]
    ses_common = mail.get("commonHeaders", {})

    from_addr  = norm(ses_common.get("from", [""])[0])
    reply_to   = norm(ses_common.get("replyTo", [""])[0])
    subject    = norm(ses_common.get("subject", ""))
    message_id = mail.get("messageId", "unknown")

    log("email_received",
        message_id=message_id,
        from_addr=from_addr,
        reply_to=reply_to,
        subject=subject
    )

    raw_mail = mail["content"]
    msg      = BytesParser(policy=policy.default).parsebytes(base64.b64decode(raw_mail))

    body      = ""
    body_part = msg.get_body(preferencelist=('plain', 'html'))
    if body_part:
        body = norm(body_part.get_content())
    if not body:
        body = ""

    attachments = []
    for part in msg.iter_attachments():
        filename   = part.get_filename()
        file_bytes = part.get_payload(decode=True)
        if not filename or not file_bytes:
            continue
        attachments.append({"filename": filename, "content": file_bytes})

    if not attachments:
        log("no_attachments",
            message_id=message_id,
            subject=subject,
            from_addr=from_addr,
            reply_to=reply_to
        )
        return {"status": "skipped", "reason": "no_attachments", "subject": subject, "from": from_addr}

    scores = {}
    for vendor, cfg in vendor_config.items():
        scores[vendor] = score_vendor(
            cfg, from_addr, reply_to, subject, body, attachments
        )

    source = max(scores, key=scores.get)
    if scores[source] == 0:
        source = "unknown"

    cfg       = vendor_config.get(source, {})
    timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H-%M-%S")
    uploaded  = []

    for att in attachments:
        filename = att["filename"].lower()
        content  = att["content"]
        if not content:
            continue

        should_upload = (
            (cfg.get("file_filter")    and any(f in filename.lower() for f in cfg["file_filter"]))or
            (cfg.get("subject_filter") and any(f in subject.lower() for f in cfg["subject_filter"]))
        )

        if not should_upload:
            log("file_skipped",
                reason="no_filter_matched",
                message_id=message_id,
                vendor_detected=source,
                filename=att["filename"],
                subject=subject,
                from_addr=from_addr,
                reply_to=reply_to
            )
            continue

        raw_key = f"pos-files/{source}/{timestamp}/{att['filename']}"
        try:
            s3.put_object(Bucket=RAW_BUCKET, Key=raw_key, Body=content)
            uploaded.append(raw_key)
            log("file_uploaded",
                message_id=message_id,
                source=source,
                filename=att["filename"],
                s3_key=raw_key,
                size_bytes=len(content)
            )
        except Exception as e:
            log("upload_error",
                message_id=message_id,
                source=source,
                filename=att["filename"],
                s3_key=raw_key,
                error=str(e)
            )
            continue

        if TRANSFORMED_BUCKET:
            try:
                output_key = process_attachment(
                    s3_client     = s3,
                    body_bytes    = content,
                    store_name    = source,
                    file_name     = att["filename"],
                    timestamp     = timestamp,
                    output_bucket = TRANSFORMED_BUCKET
                )
                if output_key:
                    log("file_transformed",
                        message_id=message_id,
                        source=source,
                        filename=att["filename"],
                        output_key=output_key
                    )
            except Exception as e:
                log("transform_error",
                    message_id=message_id,
                    source=source,
                    filename=att["filename"],
                    error=str(e)
                )

    log("email_processed",
        message_id=message_id,
        source=source,
        total_attachments=len(attachments),
        uploaded_count=len(uploaded),
        uploaded_files=uploaded
    )

    return {
        "status":         "processed",
        "source":         source,
        "scores":         scores,
        "uploaded_files": uploaded,
        "from":           from_addr,
        "reply_to":       reply_to,
        "subject":        subject
    }