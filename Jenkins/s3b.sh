#!/bin/bash

# Завантажуємо конфігурацію
source config.sh

# Перевіряємо, чи вказаний регіон
if [ -z "$AWS_REGION" ]; then
  echo "Не вказано регіон AWS. Будь ласка, вкажіть правильний регіон у конфігурації."
  exit 1
fi

# Створення архіву бекапу
BACKUP_DIR="/tmp/backup_$(date +'%Y-%m-%d_%H-%M-%S')"
mkdir -p "$BACKUP_DIR"

# Архівуємо важливі файли
echo "Архівуємо важливі файли..."
cp -r /etc /var/www /home /root $BACKUP_DIR

# Архівуємо файли Jenkins
echo "Архівуємо файли Jenkins..."
cp -r /var/lib/jenkins $BACKUP_DIR

# Створюємо архів
echo "Створюємо архів..."
ARCHIVE_NAME="instance_backup_$(date +'%Y-%m-%d_%H-%M-%S').tar.gz"
tar -czvf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$BACKUP_DIR" .

# Встановлюємо змінні середовища для AWS
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$AWS_REGION"

# Перевіряємо, чи правильно вказаний регіон
echo "Вказаний регіон AWS: $AWS_DEFAULT_REGION"

# Завантажуємо бекап в S3
echo "Завантажуємо бекап в S3..."
aws s3 cp "$BACKUP_DIR/$ARCHIVE_NAME" "s3://$BUCKET_NAME/backups/$ARCHIVE_NAME"

if [ $? -eq 0 ]; then
    echo "Бекап успішно завантажено в S3: s3://$BUCKET_NAME/backups/$ARCHIVE_NAME"
else
    echo "Не вдалося завантажити бекап в S3."
fi

# Очистка тимчасових файлів
rm -rf "$BACKUP_DIR"

