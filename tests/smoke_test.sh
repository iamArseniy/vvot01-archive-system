#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <api_gateway_url> <public_file_url>" >&2
  exit 2
fi

api_url="${1%/}"
source_url="$2"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

echo "1/6 Проверка валидации POST /tasks"
bad_status="$(curl -sS -o "$tmp_dir/bad.json" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d '{"name":"missing-url.txt"}' \
  "$api_url/tasks")"
test "$bad_status" = "400"

echo "2/6 Отправка корректного задания"
task_json="$(python3 -c 'import json,sys; print(json.dumps({"name":"demo-file.txt","url":sys.argv[1]}))' "$source_url")"
accepted_status="$(curl -sS -o "$tmp_dir/accepted.json" -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "$task_json" \
  "$api_url/tasks")"
test "$accepted_status" = "202"

echo "3/6 Ожидание обработки очереди"
archive_key=""
for _ in $(seq 1 30); do
  curl -sS "$api_url/archives" -o "$tmp_dir/archives.json"
  archive_key="$(python3 - "$tmp_dir/archives.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as stream:
    archives = json.load(stream)
print(archives[-1]["key"] if archives else "")
PY
)"
  [[ -n "$archive_key" ]] && break
  sleep 2
done
test -n "$archive_key"
echo "Ключ: $archive_key"

echo "4/6 Получение информации об архиве"
info_status="$(curl -sS -o "$tmp_dir/archive.json" -w '%{http_code}' \
  "$api_url/archives/$archive_key")"
test "$info_status" = "200"
python3 -m json.tool "$tmp_dir/archive.json"

echo "5/6 Скачивание и проверка ZIP"
download_status="$(curl -sS -o "$tmp_dir/archive.zip" -w '%{http_code}' \
  "$api_url/download/$archive_key")"
test "$download_status" = "200"
python3 -m zipfile -l "$tmp_dir/archive.zip"

echo "6/6 Проверка 404"
missing_key="00000000-0000-7000-8000-000000000000.zip"
missing_status="$(curl -sS -o "$tmp_dir/missing.json" -w '%{http_code}' \
  "$api_url/archives/$missing_key")"
test "$missing_status" = "404"

echo "Все smoke-тесты пройдены"
