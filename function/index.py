"""Yandex Cloud Function: download one file, ZIP it and store archive metadata."""

from __future__ import annotations

import json
import os
import secrets
import shutil
import tempfile
import time
import urllib.parse
import urllib.request
import uuid
import zipfile
from pathlib import Path
from typing import Any


def uuid7() -> uuid.UUID:
    """Generate an RFC 9562 UUIDv7 without a third-party dependency."""
    unix_ms = time.time_ns() // 1_000_000
    if unix_ms >= 1 << 48:
        raise OverflowError("Unix timestamp does not fit UUIDv7")
    value = (
        (unix_ms << 80)
        | (0x7 << 76)
        | (secrets.randbits(12) << 64)
        | (0b10 << 62)
        | secrets.randbits(62)
    )
    return uuid.UUID(int=value)


def _download(url: str, destination: Path) -> None:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("url must be an absolute HTTP(S) URL")

    request = urllib.request.Request(
        url,
        headers={"User-Agent": "vvot-archive-function/1.0"},
    )
    with urllib.request.urlopen(request, timeout=60) as response, destination.open("wb") as output:
        shutil.copyfileobj(response, output, length=1024 * 1024)


def _safe_filename(name: str) -> str:
    filename = Path(name.replace("\\", "/")).name.strip()
    if filename in {"", ".", ".."}:
        raise ValueError("name must contain a valid file name")
    return filename


def _aws_resources() -> tuple[Any, Any]:
    # Импорт отложен, чтобы чистые функции можно было тестировать без boto3.
    import boto3

    session = boto3.session.Session(
        aws_access_key_id=os.environ["AWS_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["AWS_SECRET_ACCESS_KEY"],
        region_name="ru-central1",
    )
    s3 = session.client("s3", endpoint_url="https://storage.yandexcloud.net")
    dynamodb = session.resource(
        "dynamodb",
        endpoint_url=os.environ["YDB_DOCUMENT_API_ENDPOINT"],
    )
    return s3, dynamodb.Table(os.environ.get("YDB_TABLE_NAME", "archives"))


def process_task(task: dict[str, Any]) -> dict[str, str]:
    name = task.get("name")
    url = task.get("url")
    if not isinstance(name, str) or not isinstance(url, str):
        raise ValueError("task must contain string fields 'name' and 'url'")

    filename = _safe_filename(name)
    key = f"{uuid7()}.zip"
    bucket = os.environ["BUCKET_NAME"]
    s3, table = _aws_resources()

    with tempfile.TemporaryDirectory(prefix="vvot-") as directory:
        source_path = Path(directory) / "source"
        archive_path = Path(directory) / key
        _download(url, source_path)

        with zipfile.ZipFile(
            archive_path,
            mode="w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=6,
        ) as archive:
            archive.write(source_path, arcname=filename)

        s3.upload_file(
            str(archive_path),
            bucket,
            key,
            ExtraArgs={"ContentType": "application/zip"},
        )

    item = {"name": name, "url": url, "key": key}
    try:
        table.put_item(Item=item)
    except Exception:
        # Не оставляем архив без записи в YDB, если сохранение метаданных не удалось.
        s3.delete_object(Bucket=bucket, Key=key)
        raise
    return item


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    messages = event.get("messages")
    if not isinstance(messages, list) or not messages:
        raise ValueError("message queue event contains no messages")

    processed = []
    for envelope in messages:
        body = envelope["details"]["message"]["body"]
        task = json.loads(body) if isinstance(body, str) else body
        if not isinstance(task, dict):
            raise ValueError("message body must be a JSON object")
        processed.append(process_task(task))

    return {"processed": len(processed), "archives": processed}
