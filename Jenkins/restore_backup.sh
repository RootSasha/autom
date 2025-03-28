#!/bin/bash

# Завантажуємо облікові дані з config.sh
source config.sh

# Перевіряємо, чи задані AWS ключі
if [[ -z "$AWS_ACCESS_KEY_ID" || -z "$AWS_SECRET_ACCESS_KEY" ]]; then
    echo "Облікові дані AWS не задані в config.sh."
    exit 1
fi

# Експортуємо облікові дані AWS для aws-cli
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$AWS_REGION

# Завантажуємо бекап з S3
echo "Завантажуємо бекап з $1..."
aws s3 cp "$1" /tmp/instance_backup.tar.gz

# Перевіряємо, чи вдалося завантажити файл
if [ ! -f /tmp/instance_backup.tar.gz ]; then
    echo "Не вдалося завантажити бекап з S3."
    exit 1
fi

# Розпаковуємо бекап
echo "Розпаковуємо бекап..."
tar -xvzf /tmp/instance_backup.tar.gz -C /

systemctl restart jenkins

echo "Бекап успішно відновлений."

#bash restore_backup.sh s3xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
