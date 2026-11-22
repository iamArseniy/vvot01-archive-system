#!/usr/bin/env python3
"""Create/delete the YDB document table through the DynamoDB-compatible API."""

from __future__ import annotations

import datetime as dt
import hashlib
import hmac
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

REGION = "ru-central1"
SERVICE = "dynamodb"
TARGETS = {
    "create": "DynamoDB_20120810.CreateTable",
    "delete": "DynamoDB_20120810.DeleteTable",
}


def _sign(key: bytes, value: str) -> bytes:
    return hmac.new(key, value.encode("utf-8"), hashlib.sha256).digest()


def _request(action: str) -> None:
    endpoint = os.environ["YDB_DOCUMENT_API_ENDPOINT"].rstrip("/")
    access_key = os.environ["AWS_ACCESS_KEY_ID"]
    secret_key = os.environ["AWS_SECRET_ACCESS_KEY"]
    table_name = os.environ.get("YDB_TABLE_NAME", "archives")

    if action == "create":
        payload = {
            "TableName": table_name,
            "BillingMode": "PAY_PER_REQUEST",
            "KeySchema": [{"AttributeName": "key", "KeyType": "HASH"}],
            "AttributeDefinitions": [{"AttributeName": "key", "AttributeType": "S"}],
        }
    else:
        payload = {"TableName": table_name}

    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    parsed = urllib.parse.urlsplit(endpoint)
    now = dt.datetime.now(dt.timezone.utc)
    amz_date = now.strftime("%Y%m%dT%H%M%SZ")
    date_stamp = now.strftime("%Y%m%d")
    target = TARGETS[action]

    canonical_uri = urllib.parse.quote(parsed.path or "/", safe="/-_.~")
    canonical_query = parsed.query
    canonical_headers = (
        "content-type:application/x-amz-json-1.0\n"
        f"host:{parsed.netloc}\n"
        f"x-amz-date:{amz_date}\n"
        f"x-amz-target:{target}\n"
    )
    signed_headers = "content-type;host;x-amz-date;x-amz-target"
    payload_hash = hashlib.sha256(body).hexdigest()
    canonical_request = "\n".join(
        ["POST", canonical_uri, canonical_query, canonical_headers, signed_headers, payload_hash]
    )

    scope = f"{date_stamp}/{REGION}/{SERVICE}/aws4_request"
    string_to_sign = "\n".join(
        [
            "AWS4-HMAC-SHA256",
            amz_date,
            scope,
            hashlib.sha256(canonical_request.encode("utf-8")).hexdigest(),
        ]
    )
    signing_key = _sign(
        _sign(_sign(_sign(("AWS4" + secret_key).encode("utf-8"), date_stamp), REGION), SERVICE),
        "aws4_request",
    )
    signature = hmac.new(signing_key, string_to_sign.encode("utf-8"), hashlib.sha256).hexdigest()
    authorization = (
        f"AWS4-HMAC-SHA256 Credential={access_key}/{scope}, "
        f"SignedHeaders={signed_headers}, Signature={signature}"
    )

    request = urllib.request.Request(
        endpoint,
        data=body,
        method="POST",
        headers={
            "Authorization": authorization,
            "Content-Type": "application/x-amz-json-1.0",
            "X-Amz-Date": amz_date,
            "X-Amz-Target": target,
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            response.read()
    except urllib.error.HTTPError as error:
        response_body = error.read().decode("utf-8", errors="replace")
        already_ok = action == "create" and "ResourceInUseException" in response_body
        already_gone = action == "delete" and "ResourceNotFoundException" in response_body
        if not (already_ok or already_gone):
            raise RuntimeError(
                f"YDB {action} failed with HTTP {error.code}: {response_body}"
            ) from error

    print(f"YDB document table '{table_name}': {action} complete")


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in TARGETS:
        raise SystemExit("Usage: manage_ydb_table.py create|delete")
    _request(sys.argv[1])


if __name__ == "__main__":
    main()
