#!/bin/bash

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="1"
TOKEN_FILE="/root/jenkins_api_token.txt"

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
hudsonRealm.createAccount("$JENKINS_USER", "$JENKINS_PASSWORD")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
instance.setAuthorizationStrategy(strategy)
instance.save()

println("✅ Адміністратор створений: $JENKINS_USER / $JENKINS_PASSWORD")
EOF

echo "🧹 Очищуємо кеш Jenkins..."
sudo rm -rf /var/lib/jenkins/jenkins.install.UpgradeWizard.state
sudo rm -rf /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion

echo "🔄 Перезапуск Jenkins..."
sudo systemctl restart jenkins

echo "⏳ Очікуємо запуск Jenkins..."
sleep 40  # Чекаємо поки Jenkins знову запуститься

echo "🔑 Отримання API-токена..."
API_TOKEN=$(curl -s -X POST "$JENKINS_URL/me/descriptorByName/jenkins.security.ApiTokenProperty/generateNewToken" \
    --user "$JENKINS_USER:$JENKINS_PASSWORD" \
    --data "newTokenName=MyToken" | jq -r '.data.tokenValue')

if [[ -z "$API_TOKEN" || "$API_TOKEN" == "null" ]]; then
    echo "❌ Помилка: Не вдалося отримати API-токен"
    exit 1
fi

echo "$API_TOKEN" | sudo tee "$TOKEN_FILE" > /dev/null
sudo chmod 600 "$TOKEN_FILE"

echo "✅ API-токен отримано та збережено в $TOKEN_FILE!"
