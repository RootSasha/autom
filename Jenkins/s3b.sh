#!/bin/bash

source /home/ubuntu/Diplome/Jenkins/config.sh

# Налаштування змінних
BACKUP_FILENAME="jenkins-backup-$(date +%Y%m%d%H%M%S).tar.gz"
JENKINS_PATH="/var/lib/jenkins"

# Налаштування AWS credentials
export AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export AWS_DEFAULT_REGION="${AWS_REGION}"

# Перевірка наявності AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Помилка: AWS CLI не встановлено."
    exit 1
fi

# Перевірка наявності S3-бакету та створення, якщо його немає
if ! aws s3 ls s3://${BUCKET_NAME} &> /dev/null; then
    echo "Створення S3-бакету ${BUCKET_NAME} в регіоні ${AWS_REGION}..."
    aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${AWS_REGION} --create-bucket-configuration LocationConstraint=${AWS_REGION}
    if [ $? -ne 0 ]; then
        echo "Помилка: не вдалося створити S3-бакет."
        exit 1
    fi
    echo "S3-бакет ${BUCKET_NAME} створено в регіоні ${AWS_REGION}."
fi

# Створення бекапу Jenkins
echo "Створення бекапу Jenkins..."
tar -czvf ${BACKUP_FILENAME} ${JENKINS_PATH}
if [ $? -ne 0 ]; then
    echo "Помилка: не вдалося створити бекап Jenkins."
    exit 1
fi
echo "Бекап Jenkins створено: ${BACKUP_FILENAME}"

# Завантаження бекапу на S3
echo "Завантаження бекапу на S3..."
aws s3 cp ${BACKUP_FILENAME} s3://${BUCKET_NAME}/${BACKUP_FILENAME} --region ${AWS_REGION}
if [ $? -ne 0 ]; then
    echo "Помилка: не вдалося завантажити бекап на S3."
    exit 1
fi
echo "Бекап завантажено на S3: s3://${BUCKET_NAME}/${BACKUP_FILENAME} в регіоні ${AWS_REGION}."

# Видалення локального бекапу (опціонально)
echo "Видалення локального бекапу..."
rm ${BACKUP_FILENAME}
echo "Локальний бекап видалено."

echo "Бекап Jenkins успішно створено та завантажено на S3."
