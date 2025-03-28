#!/bin/bash

# Завантажуємо конфігурацію
source /home/ubuntu/Diplome/Jenkins/config.sh

# Отримуємо Instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
if [ -z "$INSTANCE_ID" ]; then
  echo "Не вдалося отримати Instance ID."
  exit 1
fi

# Перевіряємо, чи вказано регіон
if [ -z "$AWS_REGION" ]; then
  echo "Не вказано регіон AWS. Будь ласка, вкажіть правильний регіон у конфігурації."
  exit 1
fi

# Створення архіву бекапу
BACKUP_DIR="/tmp/backup_${INSTANCE_ID}_$(date +'%Y-%m-%d_%H-%M-%S')"
mkdir -p "$BACKUP_DIR"

# Архівуємо файли Jenkins
echo "Архівуємо файли Jenkins..."
cp -r /var/lib/jenkins "$BACKUP_DIR"

# Створюємо архів
echo "Створюємо архів..."
ARCHIVE_NAME="instance_backup_${INSTANCE_ID}_$(date +'%Y-%m-%d_%H-%M-%S').tar.gz"
tar -czvf "$BACKUP_DIR/$ARCHIVE_NAME" -C "$BACKUP_DIR" .

# Встановлюємо змінні середовища для AWS
export AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="$AWS_REGION"

# Завантажуємо бекап в S3
echo "Завантажуємо бекап в S3..."
aws s3 cp "$BACKUP_DIR/$ARCHIVE_NAME" "s3://$BUCKET_NAME/backups/$ARCHIVE_NAME"

if [ $? -eq 0 ]; then
    echo "Бекап успішно завантажено в S3: s3://$BUCKET_NAME/backups/$ARCHIVE_NAME"
else
    echo "Не вдалося завантажити бекап в S3."
    exit 1
fi

# Визначаємо Volume ID, пов'язаний з Instance ID
echo "Отримуємо Volume ID..."
VOLUME_ID=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId" --output text)

if [ -z "$VOLUME_ID" ]; then
  echo "Не вдалося отримати Volume ID."
  exit 1
fi
echo "Volume ID: $VOLUME_ID"

# Створюємо snapshot
echo "Створюємо snapshot для Volume ID: $VOLUME_ID..."
SNAPSHOT_ID=$(aws ec2 create-snapshot --volume-id "$VOLUME_ID" --description "Snapshot for $INSTANCE_ID on $(date +'%Y-%m-%d %H:%M:%S')" --query "SnapshotId" --output text)

if [ -z "$SNAPSHOT_ID" ]; then
  echo "Не вдалося створити snapshot."
  exit 1
fi
echo "Snapshot створено: $SNAPSHOT_ID"

# Очистка тимчасових файлів
rm -rf "$BACKUP_DIR"

echo "Бекап та snapshot успішно створені!"

