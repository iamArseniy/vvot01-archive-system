resource "yandex_api_gateway" "archive" {
  folder_id   = var.folder_id
  name        = "${local.prefix}archive-api"
  description = "${local.prefix} public API for archive coursework"

  spec = templatefile("${path.module}/openapi.yaml", {
    service_account_id = yandex_iam_service_account.runtime.id
    queue_url          = yandex_message_queue.tasks.id
    folder_id          = var.folder_id
    database_path      = yandex_ydb_database_serverless.archives.database_path
    bucket_name        = yandex_storage_bucket.archives.bucket
  })

  depends_on = [
    terraform_data.archives_table,
    yandex_resourcemanager_folder_iam_member.runtime,
  ]
}
