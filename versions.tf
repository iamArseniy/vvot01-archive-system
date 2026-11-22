terraform {
  required_version = ">= 1.6.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.7"
    }
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.158.0, < 1.0.0"
    }
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = "ru-central1-a"
  # провайдер читает токен из YC_TOKEN.
}
