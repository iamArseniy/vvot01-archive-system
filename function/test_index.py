import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import index


class FakeS3:
    def __init__(self):
        self.uploaded = None
        self.deleted = None

    def upload_file(self, filename, bucket, key, ExtraArgs):
        self.uploaded = (Path(filename).read_bytes(), bucket, key, ExtraArgs)

    def delete_object(self, **kwargs):
        self.deleted = kwargs


class FakeTable:
    def __init__(self):
        self.item = None

    def put_item(self, Item):
        self.item = Item


class ArchiveFunctionTests(unittest.TestCase):
    def test_uuid7_has_expected_version_and_variant(self):
        value = index.uuid7()
        self.assertEqual(value.version, 7)
        self.assertEqual(value.variant, "specified in RFC 4122")

    def test_safe_filename_blocks_zip_slip(self):
        self.assertEqual(index._safe_filename("../../report.pdf"), "report.pdf")
        self.assertEqual(index._safe_filename(r"..\\report.pdf"), "report.pdf")

    def test_handler_archives_and_persists_message(self):
        fake_s3 = FakeS3()
        fake_table = FakeTable()

        def fake_download(url, destination):
            destination.write_bytes(b"coursework")

        event = {
            "messages": [
                {
                    "details": {
                        "message": {
                            "body": json.dumps(
                                {"name": "document.txt", "url": "https://example.com/document.txt"}
                            )
                        }
                    }
                }
            ]
        }

        with patch.dict(os.environ, {"BUCKET_NAME": "vvot00-test", "YDB_TABLE_NAME": "archives"}), patch(
            "index._aws_resources", return_value=(fake_s3, fake_table)
        ), patch("index._download", side_effect=fake_download):
            result = index.handler(event, None)

        self.assertEqual(result["processed"], 1)
        self.assertEqual(fake_table.item["name"], "document.txt")
        self.assertRegex(fake_table.item["key"], r"^[0-9a-f-]{36}\.zip$")
        self.assertEqual(fake_s3.uploaded[1], "vvot00-test")
        self.assertEqual(fake_s3.uploaded[3]["ContentType"], "application/zip")


if __name__ == "__main__":
    unittest.main()
