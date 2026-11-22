variable "cloud_id" {
  description = "Идентификатор облака Yandex Cloud"
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.cloud_id)) > 0
    error_message = "cloud_id не может быть пустым."
  }
}

variable "folder_id" {
  description = "Идентификатор каталога Yandex Cloud"
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.folder_id)) > 0
    error_message = "folder_id не может быть пустым."
  }
}

variable "bucket_name" {
  description = "Глобально уникальное имя бакета с префиксом vvotNN-"
  type        = string
  nullable    = false

  validation {
    condition = (
      length(var.bucket_name) >= 8 &&
      length(var.bucket_name) <= 63 &&
      can(regex("^vvot[0-9]{2}-[a-z0-9][a-z0-9.-]*[a-z0-9]$", var.bucket_name))
    )
    error_message = "bucket_name должен быть длиной 8–63 символа и начинаться с vvotNN-, например vvot07-archive-a1b2c3."
  }
}
