#!/bin/bash

echo "🔄 Оновлення системи та встановлення необхідних компонентів..."
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y openjdk-17-jdk curl unzip jq

echo "🔑 Додаємо офіційний репозиторій Jenkins..."
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

echo "📦 Встановлення Jenkins..."
sudo apt update -y
sudo apt install -y jenkins

echo "🚀 Запуск Jenkins..."
sudo systemctl enable --now jenkins

echo "⏳ Очікуємо запуск Jenkins..."
sleep 40  # Даємо час Jenkins запуститися

echo "📌 Перевірка стану Jenkins..."
if ! systemctl is-active --quiet jenkins; then
    echo "❌ Помилка: Jenkins не запустився!"
    exit 1
fi

echo "✅ Jenkins встановлено успішно!"

