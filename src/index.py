import json
import logging
import os

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def handler(event, context):
    logger.info("Event: %s", json.dumps(event))
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "ok"}),
    }
