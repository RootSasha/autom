#!/bin/bash

echo "🔄 Оновлення системи та встановлення необхідних компонентів..."
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y openjdk-17-jdk curl unzip

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

echo "📌 Переконуємось, що Jenkins працює..."
if ! systemctl is-active --quiet jenkins; then
    echo "❌ Помилка: Jenkins не запустився!"
    exit 1
fi

echo "⚙️ Створюємо Groovy-скрипт для автоматичного створення адміністратора..."
sudo mkdir -p /var/lib/jenkins/init.groovy.d
cat <<EOF | sudo tee /var/lib/jenkins/init.groovy.d/basic-security.groovy
#!groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstanceOrNull()
if (instance == null) {
    println("❌ Помилка: неможливо отримати інстанс Jenkins")
    return
}

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "1")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)
instance.save()

println("✅ Адміністратор створений: admin / 1")
EOF

echo "🧹 Очищуємо кеш Jenkins для застосування змін..."
sudo rm -rf /var/lib/jenkins/jenkins.install.UpgradeWizard.state
sudo rm -rf /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

echo "🔄 Перезапуск Jenkins..."
sudo systemctl restart jenkins

echo "✅ Jenkins встановлено та налаштовано!"
echo "🔹 Логін: admin"
echo "🔹 Пароль: 1"

echo "Інсталяція плагінів"
bash seting/plugin.sh
