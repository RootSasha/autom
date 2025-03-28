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

# Функція для відновлення бекапу
restore_backup() {
    read -p "Введіть S3 URI бекапу (наприклад, s3://bucket-name/backups/backup.tar.gz): " S3_URI
    echo "Завантажуємо бекап з $S3_URI..."
    aws s3 cp "$S3_URI" /tmp/instance_backup.tar.gz

    if [ ! -f /tmp/instance_backup.tar.gz ]; then
        echo "Не вдалося завантажити бекап з S3."
        exit 1
    fi

    echo "Розпаковуємо бекап..."
    tar -xvzf /tmp/instance_backup.tar.gz -C /

    systemctl restart jenkins
    echo "Бекап успішно відновлений."
}

# Функція для відновлення зі снапшота
restore_snapshot() {
    read -p "Введіть Snapshot ID (наприклад, snap-xxxxxxxxxxxxxxxxx): " SNAPSHOT_ID
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    if [ -z "$INSTANCE_ID" ]; then
      echo "Не вдалося отримати Instance ID."
      exit 1
    fi

    echo "Створюємо новий том із снапшота $SNAPSHOT_ID..."
    VOLUME_ID=$(aws ec2 create-volume --snapshot-id "$SNAPSHOT_ID" --availability-zone $(aws ec2 describe-instances --instance-id "$INSTANCE_ID" --query "Reservations[0].Instances[0].Placement.AvailabilityZone" --output text) --query "VolumeId" --output text)
    echo "Створено новий том: $VOLUME_ID"

    echo "Очікуємо, поки том стане доступним..."
    aws ec2 wait volume-available --volume-ids "$VOLUME_ID"

    echo "Прикріплюємо том до інстансу..."
    aws ec2 attach-volume --volume-id "$VOLUME_ID" --instance-id "$INSTANCE_ID" --device /dev/xvdf

    echo "Снапшот успішно відновлено."
}

# Головне меню
echo "Що ви хочете відновити?"
echo "1) Бекап із S3"
echo "2) Снапшот EBS"
echo "3) Відновити і бекап, і снапшот"
read -p "Виберіть опцію (1/2/3): " CHOICE

case $CHOICE in
    1) restore_backup ;;
    2) restore_snapshot ;;
    3) restore_backup && restore_snapshot ;;
    *) echo "Невірний вибір."; exit 1 ;;
esac

