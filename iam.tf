resource "yandex_iam_service_account" "runtime" {
  folder_id   = var.folder_id
  name        = "${local.prefix}runtime-sa"
  description = "${local.prefix} service account for API Gateway, trigger and archive function"
}

resource "yandex_iam_service_account" "provisioner" {
  folder_id   = var.folder_id
  name        = "${local.prefix}provisioner-sa"
  description = "${local.prefix} service account for Terraform-compatible S3 and YMQ APIs"
}

resource "yandex_resourcemanager_folder_iam_member" "runtime" {
  for_each  = local.runtime_roles
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.runtime.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "provisioner" {
  for_each  = local.provisioner_roles
  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.provisioner.id}"
}

resource "yandex_iam_service_account_static_access_key" "runtime" {
  service_account_id = yandex_iam_service_account.runtime.id
  description        = "${local.prefix} function access to Object Storage and YDB Document API"

  depends_on = [yandex_resourcemanager_folder_iam_member.runtime]
}

resource "yandex_iam_service_account_static_access_key" "provisioner" {
  service_account_id = yandex_iam_service_account.provisioner.id
  description        = "${local.prefix} Terraform access to Object Storage and Message Queue"

  depends_on = [yandex_resourcemanager_folder_iam_member.provisioner]
}
