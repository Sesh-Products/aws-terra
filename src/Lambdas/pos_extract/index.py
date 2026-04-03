import os
import json
import re
import boto3
from email import policy
from email.parser import BytesParser
from datetime import datetime

s3             = boto3.client("s3")
lambda_client  = boto3.client("lambda")
ses_client = boto3.client("ses", region_name="us-east-1")

def log(event_name, **kwargs):
    print(json.dumps({"event": event_name, "timestamp": datetime.utcnow().isoformat(), **kwargs}))

def norm(s):
    return s.lower() if isinstance(s, str) else ""

def score_vendor(cfg, from_addr, reply_to, subject, body, attachments):
    score      = 0
    keywords   = cfg.get("keywords", [])
    from_emails = cfg.get("from_email", [])

    # Check from_email first — strong signal
    for email in from_emails:
        if email.lower() in from_addr:
            score += 3

    for k in keywords:
        if k in from_addr: score += 1
        if k in reply_to:  score += 1
        if k in subject:   score += 1
        if k in body:      score += 1

    if cfg.get("subject_filter") and any(f in subject for f in cfg["subject_filter"]):
        score += 1

    for att in attachments:
        for k in keywords:
            if k in att["filename"].lower():
                score += 1

    return score


def handler(event, context):
    RAW_BUCKET         = os.environ.get("RAW_BUCKET_EMAIL")
    vendor_config      = json.loads(os.environ.get("VENDOR_CONFIG", "{}"))
    EC2_TRIGGER_LAMBDA = os.environ.get("EC2_TRIGGER_LAMBDA")
    NIELSEN_FROM_EMAIL = os.environ.get("NIELSEN_FROM_EMAIL")

    if not RAW_BUCKET:
        log("config_error", reason="RAW_BUCKET_EMAIL environment variable is missing")
        raise ValueError("RAW_BUCKET_EMAIL environment variable is missing")

    if not vendor_config:
        log("config_error", reason="VENDOR_CONFIG is missing or empty")
        raise ValueError("VENDOR_CONFIG is missing or empty")

    # ── Get email ────────────────────────────────────────────────────────────
    record = event["Records"][0]

    if "ses" in record:
        message_id = record["ses"]["mail"].get("messageId", "unknown")
        s3_key     = f"ses-emails/{message_id}"
        log("reading_from_s3", message_id=message_id, s3_key=s3_key)
        response   = s3.get_object(Bucket=RAW_BUCKET, Key=s3_key)
        raw_email  = response["Body"].read()

    elif "s3" in record:
        bucket     = record["s3"]["bucket"]["name"]
        s3_key     = record["s3"]["object"]["key"]
        message_id = s3_key.split("/")[-1]
        log("reading_from_s3", message_id=message_id, s3_key=s3_key)
        response   = s3.get_object(Bucket=bucket, Key=s3_key)
        raw_email  = response["Body"].read()

    else:
        # Fallback — get latest file from ses-emails/ prefix
        log("fallback_latest_file", reason="no ses or s3 record found")
        paginator   = s3.get_paginator("list_objects_v2")
        pages       = paginator.paginate(Bucket=RAW_BUCKET, Prefix="ses-emails/")
        all_objects = []
        for page in pages:
            all_objects.extend(page.get("Contents", []))

        if not all_objects:
            log("no_emails_found", reason="no files in ses-emails/")
            return {"status": "skipped", "reason": "no_emails_found"}

        latest     = max(all_objects, key=lambda x: x["LastModified"])
        s3_key     = latest["Key"]
        message_id = s3_key.split("/")[-1]
        log("latest_file_found", s3_key=s3_key, message_id=message_id)
        response   = s3.get_object(Bucket=RAW_BUCKET, Key=s3_key)
        raw_email  = response["Body"].read()
    
    if not raw_email:
        log("email_empty", message_id=message_id)
        return {"status": "skipped", "reason": "empty_email"}
    
    # ── Parse email ──────────────────────────────────────────────────────────
    msg         = BytesParser(policy=policy.default).parsebytes(raw_email)
    ses_from    = msg.get("From", "")
    ses_reply   = msg.get("Reply-To", "")
    ses_subject = msg.get("Subject", "")

    from_addr  = norm(ses_from)
    reply_to   = norm(ses_reply)
    subject    = norm(ses_subject)
    raw_subject = ses_subject  # ← keep original case for report name extraction

    if not from_addr:
        log("email_no_sender", message_id=message_id)
        return {"status": "skipped", "reason": "no_sender"}

    log("email_received", message_id=message_id, from_addr=from_addr,
        reply_to=reply_to, subject=subject)

    # ── Parse body ───────────────────────────────────────────────────────────
    body      = ""
    body_part = msg.get_body(preferencelist=('plain', 'html'))
    if body_part:
        body = norm(body_part.get_content())

    # ── Parse attachments ────────────────────────────────────────────────────
    attachments = []
    for part in msg.iter_attachments():
        filename   = part.get_filename()
        file_bytes = part.get_payload(decode=True)
        if not filename or not file_bytes:
            continue
        attachments.append({"filename": filename, "content": file_bytes})

    if NIELSEN_FROM_EMAIL in from_addr and EC2_TRIGGER_LAMBDA:
        raw_body  = ""
        body_part = msg.get_body(preferencelist=('plain', 'html'))
        if body_part:
            raw_body = body_part.get_content()

        log("nielsen_email_body", body=raw_body[:500])  # ← debug, remove later

        # Try multiple patterns against body
        match = (
            re.search(r'run (.+?) is now available', raw_body, re.IGNORECASE) or
            re.search(r'Data on Demand run (.+?) is',    raw_body, re.IGNORECASE) or
            re.search(r'your (.+?) is now available',    raw_body, re.IGNORECASE)
        )

        report_name = match.group(1).strip() if match else None

        if report_name:
            log("nielsen_notification_detected", report_name=report_name)
            lambda_client.invoke(
                FunctionName   = EC2_TRIGGER_LAMBDA,
                InvocationType = "Event",
                Payload        = json.dumps({"report_name": report_name})
            )
            log("ec2_trigger_invoked", report_name=report_name)
        else:
            log("report_name_not_found", subject=raw_subject, body_preview=raw_body[:200])

        return {"status": "ec2_triggered", "report_name": report_name}

    # ── Score vendor ─────────────────────────────────────────────────────────
    scores = {}
    for vendor, cfg in vendor_config.items():
        scores[vendor] = score_vendor(cfg, from_addr, reply_to, subject, body, attachments)

    source = max(scores, key=scores.get)
    if scores[source] == 0:
        NOTIFY_EMAIL = os.environ.get("NOTIFY_EMAIL")
        log("unknown_vendor", from_addr=from_addr, subject=subject, scores=scores)
        if NOTIFY_EMAIL:
            try:
                ses_client.send_email(
                    Source      = NOTIFY_EMAIL,
                    Destination = {"ToAddresses": [NOTIFY_EMAIL]},
                    Message     = {
                        "Subject": {
                            "Data": "⚠️ Unknown Vendor Detected — POS Extract"
                        },
                        "Body": {
                            "Text": {
                                "Data": f"An email was received from an unknown vendor.\n\n"
                                        f"From: {from_addr}\n"
                                        f"Subject: {subject}\n"
                                        f"Message ID: {message_id}\n\n"
                                        f"Vendor scores: {scores}\n\n"
                                        f"Please update VENDOR_CONFIG to include this vendor."
                            }
                        }
                    }
                )
                log("unknown_vendor_alert_sent", notify_email=NOTIFY_EMAIL)
            except Exception as e:
                log("alert_email_failed", error=str(e))
        return {"status": "skipped", "reason": "unknown_vendor"}

    cfg       = vendor_config.get(source, {})
    timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H-%M-%S")
    uploaded  = []

    # ── Upload attachments ───────────────────────────────────────────────────
    for att in attachments:
        filename = att["filename"].lower()
        content  = att["content"]
        if not content:
            continue

        should_upload = (
            (cfg.get("file_filter")    and any(f in filename for f in cfg["file_filter"])) or
            (cfg.get("subject_filter") and any(f in subject  for f in cfg["subject_filter"]))
        )

        if not should_upload:
            log("file_skipped", reason="no_filter_matched", message_id=message_id,
                filename=att["filename"])
            continue

        raw_key = f"pos-files/{source}/{att['filename']}"
        try:
            s3.put_object(Bucket=RAW_BUCKET, Key=raw_key, Body=content)
            uploaded.append(raw_key)
            log("file_uploaded", message_id=message_id, source=source,
                filename=att["filename"], s3_key=raw_key, size_bytes=len(content))
        except Exception as e:
            log("upload_error", message_id=message_id, source=source,
                filename=att["filename"], error=str(e))

    log("email_processed", message_id=message_id, source=source,
        uploaded_count=len(uploaded), uploaded_files=uploaded)

    return {
        "status":         "processed",
        "source":         source,
        "uploaded_files": uploaded
    }