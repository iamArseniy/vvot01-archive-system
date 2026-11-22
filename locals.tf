locals {
  prefix = "vvot01-"

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
