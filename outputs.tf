output "api_gateway_url" {
  description = "Служебный домен API-шлюза"
  value       = "https://${yandex_api_gateway.archive.domain}"
}

output "swagger_url" {
  description = "Swagger UI для обзора и ручного тестирования"
  value       = "https://${yandex_api_gateway.archive.domain}/docs"
}

output "bucket_name" {
  description = "Имя приватного бакета с ZIP-архивами"
  value       = yandex_storage_bucket.archives.bucket
}

output "failed_tasks_queue_url" {
  description = "URL очереди необработанных заданий"
  value       = yandex_message_queue.failed_tasks.id
}
