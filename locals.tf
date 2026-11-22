locals {
  # Номер студента извлекается из bucket_name, поэтому входных переменных ровно три.
  prefix = substr(var.bucket_name, 0, 7)

  runtime_roles = toset([
    "functions.functionInvoker",
    "storage.editor",
    "ydb.editor",
    "ymq.reader",
    "ymq.writer",
  ])

  provisioner_roles = toset([
    "storage.editor",
    "ymq.admin",
  ])
}
