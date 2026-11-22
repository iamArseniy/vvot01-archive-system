resource "yandex_ydb_database_serverless" "archives" {
  folder_id           = var.folder_id
  name                = "${local.prefix}archives-db"
  deletion_protection = false

  serverless_database {
    enable_throttling_rcu_limit = true
    throttling_rcu_limit        = 10
    storage_size_limit          = 1024 * 1024 * 1024
  }
}

# Провайдер Yandex создаёт обычные YDB-таблицы, а по заданию нужна документная.
# Поэтому CreateTable выполняется совместимым DynamoDB HTTP API. Скрипт использует
# только стандартную библиотеку Python и SigV4, без AWS CLI и четвёртой переменной.
resource "terraform_data" "archives_table" {
  input = {
    endpoint   = yandex_ydb_database_serverless.archives.document_api_endpoint
    access_key = yandex_iam_service_account_static_access_key.runtime.access_key
    secret_key = yandex_iam_service_account_static_access_key.runtime.secret_key
  }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/manage_ydb_table.py create"
    environment = {
      YDB_DOCUMENT_API_ENDPOINT = self.input.endpoint
      AWS_ACCESS_KEY_ID         = self.input.access_key
      AWS_SECRET_ACCESS_KEY     = self.input.secret_key
      YDB_TABLE_NAME            = "archives"
    }
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "python3 ${path.module}/scripts/manage_ydb_table.py delete"
    environment = {
      YDB_DOCUMENT_API_ENDPOINT = self.input.endpoint
      AWS_ACCESS_KEY_ID         = self.input.access_key
      AWS_SECRET_ACCESS_KEY     = self.input.secret_key
      YDB_TABLE_NAME            = "archives"
    }
  }
}
