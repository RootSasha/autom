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

echo "Що ви хочете відновити?"
echo "1) Бекап із S3"
echo "2) Снапшот EBS"
echo "3) Відновити і бекап, і снапшот"
read -p "Виберіть опцію (1/2/3): " option

case $option in
    1)
        echo "Вибрано відновлення з бекапу S3"
        # Запитуємо шлях до бекапу на S3
        read -p "Введіть URL бекапу на S3: " s3_backup_url
        # Завантажуємо бекап з S3
        aws s3 cp "$s3_backup_url" /tmp/instance_backup.tar.gz
        
        # Перевіряємо, чи вдалося завантажити бекап
        if [ ! -f /tmp/instance_backup.tar.gz ]; then
            echo "Не вдалося завантажити бекап з S3."
            exit 1
        fi

        # Розпаковуємо бекап
        echo "Розпаковуємо бекап..."
        tar -xvzf /tmp/instance_backup.tar.gz -C /
        systemctl restart jenkins
        echo "Бекап успішно відновлений."
        ;;
    
    2)
        echo "Вибрано відновлення зі снапшоту EBS"
        # Запитуємо ID снапшоту
        read -p "Введіть Snapshot ID (наприклад, snap-xxxxxxxxxxxxxxxxx): " snapshot_id
        echo "Створюємо новий том зі снапшоту $snapshot_id..."
        
        # Створення нового тому з снапшота
        volume_id=$(aws ec2 create-volume --snapshot-id $snapshot_id --availability-zone $AWS_REGION --query 'Volume.Id' --output text)

        # Перевіряємо, чи створено том
        if [ -z "$volume_id" ]; then
            echo "Не вдалося створити том."
            exit 1
        fi

        echo "Том створений: $volume_id. Чекаємо, поки він стане доступним..."

        # Очікуємо, поки том стане доступним
        aws ec2 wait volume-available --volume-id $volume_id
        
        # Прикріплюємо том до інстансу
        instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf

        echo "Снапшот успішно відновлено."
        ;;

    3)
        echo "Вибрано відновлення і бекапу, і снапшоту"
        
        # Запитуємо шлях до бекапу на S3
        read -p "Введіть URL бекапу на S3: " s3_backup_url
        # Завантажуємо бекап з S3
        aws s3 cp "$s3_backup_url" /tmp/instance_backup.tar.gz
        
        # Перевіряємо, чи вдалося завантажити бекап
        if [ ! -f /tmp/instance_backup.tar.gz ]; then
            echo "Не вдалося завантажити бекап з S3."
            exit 1
        fi

        # Розпаковуємо бекап
        echo "Розпаковуємо бекап..."
        tar -xvzf /tmp/instance_backup.tar.gz -C /
        systemctl restart jenkins
        echo "Бекап успішно відновлений."

        # Запитуємо ID снапшоту
        read -p "Введіть Snapshot ID (наприклад, snap-xxxxxxxxxxxxxxxxx): " snapshot_id
        echo "Створюємо новий том зі снапшоту $snapshot_id..."
        
        # Створення нового тому з снапшота
        volume_id=$(aws ec2 create-volume --snapshot-id $snapshot_id --availability-zone $AWS_REGION --query 'Volume.Id' --output text)

        # Перевіряємо, чи створено том
        if [ -z "$volume_id" ]; then
            echo "Не вдалося створити том."
            exit 1
        fi

        echo "Том створений: $volume_id. Чекаємо, поки він стане доступним..."

        # Очікуємо, поки том стане доступним
        aws ec2 wait volume-available --volume-id $volume_id
        
        # Прикріплюємо том до інстансу
        instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        aws ec2 attach-volume --volume-id $volume_id --instance-id $instance_id --device /dev/sdf

        echo "Снапшот успішно відновлено."

        ;;

    *)
        echo "Невірна опція. Завершення роботи скрипту."
        exit 1
        ;;
esac

# Завантаження Docker-образів для відновлення
echo "Завантажуємо Docker-образи для відновлення..."

# Завантажуємо Docker-образи
docker pull sasha22mk/test-site:front
docker pull sasha22mk/test-site:bek
docker pull sasha22mk/test-site:2022-latest

# Запускаємо контейнери
echo "Запускаємо контейнери..."

docker run -d -p 81:80 --name front --network baza sasha22mk/test-site:front
docker run -d -p 5034:5034 --name bek --network baza sasha22mk/test-site:bek
docker run -d -p 1433:1433 --name sql --network baza sasha22mk/test-site:2022-latest

echo "Контейнери успішно запущені."

