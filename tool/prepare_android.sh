#!/usr/bin/env bash
# Генерирует папку android/ (если её нет) и приводит конфигурацию
# к application id com.aitarot.app. Запускать из корня проекта:
#   bash tool/prepare_android.sh
set -euo pipefail

if [ ! -d android ]; then
  echo "==> android/ отсутствует, генерирую платформенные файлы"
  flutter create --org com.aitarot --project-name ai_tarot --platforms=android .
fi

python3 tool/prepare_android.py
