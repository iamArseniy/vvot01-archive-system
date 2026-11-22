resource "yandex_message_queue" "failed_tasks" {
  name                      = "${local.prefix}failed-tasks"
  message_retention_seconds = 14 * 24 * 60 * 60
  access_key                = yandex_iam_service_account_static_access_key.provisioner.access_key
  secret_key                = yandex_iam_service_account_static_access_key.provisioner.secret_key
}

resource "yandex_message_queue" "tasks" {
  name                       = "${local.prefix}tasks"
  visibility_timeout_seconds = 900
  receive_wait_time_seconds  = 20
  message_retention_seconds  = 24 * 60 * 60
  access_key                 = yandex_iam_service_account_static_access_key.provisioner.access_key
  secret_key                 = yandex_iam_service_account_static_access_key.provisioner.secret_key

  redrive_policy = jsonencode({
    deadLetterTargetArn = yandex_message_queue.failed_tasks.arn
    maxReceiveCount     = 1
  })
}
