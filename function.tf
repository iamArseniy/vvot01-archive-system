data "archive_file" "archive_function" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/function.zip"
  excludes    = ["test_index.py", "__pycache__"]
}

resource "yandex_function" "archive" {
  folder_id          = var.folder_id
  name               = "${local.prefix}archive-function"
  description        = "${local.prefix} downloads a file, creates a UUIDv7 ZIP and stores metadata"
  runtime            = "python312"
  entrypoint         = "index.handler"
  memory             = 256
  execution_timeout  = 600
  service_account_id = yandex_iam_service_account.runtime.id
  user_hash          = data.archive_file.archive_function.output_base64sha256

  environment = {
    AWS_ACCESS_KEY_ID         = yandex_iam_service_account_static_access_key.runtime.access_key
    AWS_SECRET_ACCESS_KEY     = yandex_iam_service_account_static_access_key.runtime.secret_key
    AWS_DEFAULT_REGION        = "ru-central1"
    BUCKET_NAME               = yandex_storage_bucket.archives.bucket
    YDB_DOCUMENT_API_ENDPOINT = yandex_ydb_database_serverless.archives.document_api_endpoint
    YDB_TABLE_NAME            = "archives"
  }

  content {
    zip_filename = data.archive_file.archive_function.output_path
  }

  depends_on = [
    terraform_data.archives_table,
    yandex_resourcemanager_folder_iam_member.runtime,
  ]
}

resource "yandex_function_trigger" "tasks" {
  folder_id   = var.folder_id
  name        = "${local.prefix}tasks-trigger"
  description = "${local.prefix} invokes archive function for one YMQ message"

  function {
    id                 = yandex_function.archive.id
    tag                = "$latest"
    service_account_id = yandex_iam_service_account.runtime.id
  }

  message_queue {
    queue_id           = yandex_message_queue.tasks.arn
    service_account_id = yandex_iam_service_account.runtime.id
    batch_size         = 1
    batch_cutoff       = 0
  }

  depends_on = [yandex_resourcemanager_folder_iam_member.runtime]
}
