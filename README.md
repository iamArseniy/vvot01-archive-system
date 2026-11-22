# Контрольная работа № 1 — система архивирования

## Что реализовано

- `POST /tasks` проверяет JSON `{name, url}`, отправляет его в Yandex Message
  Queue и возвращает `202 Accepted`; некорректный запрос получает `400`.
- Триггер получает ровно одно сообщение без ожидания и вызывает функцию.
- Функция скачивает файл, создаёт архив с ключом `<uuid_v7>.zip`, сохраняет его
  в закрытом Object Storage и добавляет метаданные в документную таблицу YDB.
- Ошибка обработки после первой попытки переводит сообщение в DLQ.
- `GET /archives` возвращает список, `GET /archives/{key}` — одну запись или
  `404`, `GET /download/{key}` — ZIP или `404`.
- `/docs` открывает Swagger UI на служебном домене API Gateway.
- Одна Terraform-конфигурация создаёт сервисные аккаунты, роли и все ресурсы.

## Структура

```text
openapi.yaml                 OpenAPI и интеграции API Gateway
function/index.py            облачная функция
function/test_index.py       модульные тесты
scripts/manage_ydb_table.py  создание документной таблицы через Document API
tests/smoke_test.sh          сквозная проверка развёрнутой системы
*.tf                         Terraform-конфигурация
```

## Почему входных переменных ровно три

Конфигурация принимает только `cloud_id`, `folder_id`, `bucket_name`. Номер
студента зафиксирован в конфигурации: все именуемые ресурсы получают префикс
`vvot01-`.

## Предварительные условия

- Terraform 1.6 или новее;
- Python 3 (нужен локально только для создания документной таблицы);
- Yandex Cloud CLI `yc` с выбранными облаком и каталогом;
- активный платёжный аккаунт и права на создание ресурсов/назначение ролей.

`scripts/manage_ydb_table.py` сам подписывает запрос Document API по AWS Signature V4.

## Настройка и развёртывание

1. Скопируйте пример и впишите `cloud_id` и `folder_id` того облака, в котором
   запускается проект. Префикс `vvot01-` уже установлен; изменять нужно только
   уникальный суффикс имени бакета:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Передайте IAM-токен только через переменную окружения:

   ```bash
   export YC_TOKEN="$(yc iam create-token)"
   ```

3. Проверьте и разверните:

   ```bash
   terraform init
   terraform fmt -check -recursive
   terraform validate
   terraform plan -out main.tfplan
   terraform apply main.tfplan
   ```

4. Получите адреса:

   ```bash
   terraform output -raw api_gateway_url
   terraform output -raw swagger_url
   ```

Создание ролей иногда распространяется в IAM несколько десятков секунд. Если
первое применение получило ошибку доступа сразу после создания роли, повторите
`terraform apply`: операции идемпотентны.

## Проверка

Модульные тесты функции не требуют облака или `boto3`:

```bash
python3 -m unittest discover -s function -p 'test_*.py' -v
```

Полная проверка после развёртывания (второй аргумент должен быть публичной
ссылкой на небольшой файл):

```bash
./tests/smoke_test.sh \
  "$(terraform output -raw api_gateway_url)" \
  "https://example.org/path/to/a-small-public-file.txt"
```

Отдельный пример запроса:

```bash
curl -i \
  -H 'Content-Type: application/json' \
  -d '{"name":"document.pdf","url":"https://example.com/document.pdf"}' \
  "$(terraform output -raw api_gateway_url)/tasks"
```

## Удаление

```bash
terraform destroy
```

Бакет создаётся с `force_destroy = true`, поэтому тестовые ZIP-файлы удалятся
вместе с ним. Это сделано специально для обязательной демонстрации удаления
ресурсов в скринкасте.

## Существенные детали реализации

- Yandex-провайдер Terraform умеет создавать строковые YDB-таблицы, но здесь
  нужна документная. Ресурс `terraform_data.archives_table` вызывает
  DynamoDB-совместимый Document API и создаёт `archives` в том же `apply`.
- Статические ключи требуются AWS-совместимым API Object Storage, YMQ и YDB.
  Они создаются Terraform и поэтому находятся в state. State нельзя публиковать;
  он исключён через `.gitignore`. Для командной работы используйте защищённый
  удалённый backend.
- В функции имя файла нормализуется перед записью в ZIP, чтобы исключить ZIP
  Slip. Если `PutItem` не удался, уже загруженный объект удаляется.
- Функция использует временные файлы и потоковое копирование, поэтому исходный
  файл не удерживается целиком в оперативной памяти.

