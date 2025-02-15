#!/bin/bash

JENKINS_URL="http://localhost:8080"  # Адреса Jenkins
JENKINS_USER="admin"                 # Логін адміністратора
JENKINS_PASSWORD="1167b4ceaec1d7fdfe055da3790f444c4b"                  # Пароль адміністратора
CREDENTIAL_ID="ssh-key-jenkins"       # ID для credentials
SSH_KEY_PATH="/root/.ssh/id_ed25519"  # Шлях до SSH-ключа

# 🔍 Перевіряємо, чи існує SSH-ключ
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "🔑 SSH-ключ не знайдено, створюємо новий..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" -q
    echo "✅ Новий SSH-ключ створено!"
else
    echo "✅ SSH-ключ вже існує!"
fi

# Читаємо приватний та публічний ключ
SSH_PRIVATE_KEY=$(cat "$SSH_KEY_PATH")
SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")

# 🔄 Отримуємо Crumb
CRUMB=$(curl -s -u "$JENKINS_USER:$JENKINS_PASSWORD" "$JENKINS_URL/crumbIssuer/api/json" | jq -r '.crumb')

# 🔥 Groovy-скрипт для додавання Global SSH Credentials у Jenkins
GROOVY_SCRIPT=$(cat <<EOF
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*

def instance = Jenkins.getInstanceOrNull()
if (instance == null) {
    println("❌ Помилка: неможливо отримати інстанс Jenkins")
    return
}

def credentialsStore = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

// 🛠️ Перевіряємо, чи існують credentials із таким ID
def existingCred = credentialsStore.getCredentials(Domain.global()).find { it.id == "$CREDENTIAL_ID" }
if (existingCred) {
    println("🔄 Credentials '$CREDENTIAL_ID' вже існують. Видаляємо для оновлення...")
    credentialsStore.removeCredentials(Domain.global(), existingCred)
}

// 🌍 Створюємо Global SSH Username with Private Key
def sshKey = new BasicSSHUserPrivateKey( (
    CredentialsScope.GLOBAL,  // ВАЖЛИВО: робить credentials глобальними
    "$CREDENTIAL_ID",
    "jenkins",  // Користувач для SSH
    new BasicSSHUserPrivateKey.DirectEntryPrivateKeySource("""$SSH_PRIVATE_KEY"""),
    "",
    "Автоматично створені Global SSH credentials"
)

credentialsStore.addCredentials(Domain.global(), sshKey)
instance.save()

println("✅ Global SSH credentials '$CREDENTIAL_ID' (SSH Username with Private Key) додано успішно!")
EOF
)

# 🚀 Виконуємо Groovy-скрипт через Jenkins API
echo "🚀 Додаємо Global SSH credentials у Jenkins..."
curl -X POST -u "$JENKINS_USER:$JENKINS_PASSWORD" \
     -H "Jenkins-Crumb:$CRUMB" \
     --data-urlencode "script=$GROOVY_SCRIPT" "$JENKINS_URL/scriptText"

echo "✅ Завершено!"
echo "🔹 Публічний ключ (додай його на сервер!):"
echo "$SSH_PUBLIC_KEY"
