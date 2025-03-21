#!/bin/bash

echo "Оновлення системи та встановлення необхідних компонентів..."
sudo apt update -y && sudo apt upgrade -y
sudo apt install -y openjdk-17-jdk curl unzip docker-compose git

echo " Додаємо репозиторій GitHub CLI..."
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

echo " Встановлення GitHub CLI..."
sudo apt update -y
sudo apt install -y gh

echo "Додаємо офіційний репозиторій Jenkins..."
curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

echo "Встановлення Jenkins..."
sudo apt update -y
sudo apt install -y jenkins

echo "Запуск Jenkins..."
sudo systemctl enable --now jenkins

echo "⏳ Очікуємо запуск Jenkins..."
sleep 40  # Даємо час Jenkins запуститися

echo "Переконуємось, що Jenkins працює..."
if ! systemctl is-active --quiet jenkins; then
    echo "❌ Помилка: Jenkins не запустився!"
    sudo systemctl status jenkins.service
    sudo journalctl -xe -u jenkins.service
    exit 1
fi

echo "⚙️ Завантаження jenkins-cli.jar у репозиторій..."
mkdir -p jenkins_files
JENKINS_URL="http://16.16.217.80:8080"
CLI_JAR="jenkins_files/jenkins-cli.jar"

if [ ! -f "$CLI_JAR" ]; then
    curl -sSL "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" -o "$CLI_JAR"
    chmod +x "$CLI_JAR"
    echo "✅ jenkins-cli.jar збережено у jenkins_files!"
else
    echo "✅ jenkins-cli.jar вже існує у jenkins_files!"
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

bash plugin.sh

# Видалення файлів для обходу Setup Wizard
sudo rm -rf /var/lib/jenkins/jenkins.install.UpgradeWizard.state
sudo rm -rf /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

echo "Перезапуск Jenkins..."
sudo systemctl restart jenkins

bash cred.sh

bash pipeline.sh

echo "✅ Jenkins встановлено та налаштовано!"
echo "Логін: admin"
echo "Пароль: 1"
