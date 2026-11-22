resource "yandex_storage_bucket" "archives" {
  bucket     = var.bucket_name
  folder_id  = var.folder_id
  access_key = yandex_iam_service_account_static_access_key.provisioner.access_key
  secret_key = yandex_iam_service_account_static_access_key.provisioner.secret_key

  force_destroy = true
  max_size      = 10 * 1024 * 1024 * 1024

  anonymous_access_flags {
    read        = false
    list        = false
    config_read = false
  }
}
