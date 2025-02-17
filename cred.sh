#!/bin/bash

SSH_KEY_PATH="/root/.ssh/id_ed25519"
GITHUB_EMAIL="xxxxxxxxxxxxx@gmail.com"
CREDENTIAL_ID="ssh-key-jenkins"
GROOVY_SCRIPT_PATH="/var/lib/jenkins/init.groovy.d/add-ssh-credentials.groovy"

# 🗑 Видаляємо старі SSH-ключі, якщо вони є
if [[ -f "$SSH_KEY_PATH" || -f "$SSH_KEY_PATH.pub" ]]; then
    echo "🗑 Видаляємо старі SSH-ключі..."
    rm -f "$SSH_KEY_PATH" "$SSH_KEY_PATH.pub"
fi

# 🔑 Створюємо новий SSH-ключ
echo "🔑 Генеруємо новий SSH-ключ..."
ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -C "$GITHUB_EMAIL" -N "" -q
echo "✅ Новий SSH-ключ створено!"

# Читаємо приватний та публічний ключ
SSH_PRIVATE_KEY=$(cat "$SSH_KEY_PATH")
SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")

# 📌 Записуємо SSH-ключ у файл для подальшого використання
PRIVATE_KEY_FILE="/root/jenkins_ssh_key.txt"
echo "$SSH_PRIVATE_KEY" | sudo tee "$PRIVATE_KEY_FILE" > /dev/null
sudo chmod 600 "$PRIVATE_KEY_FILE"

# 📌 Записуємо Groovy-скрипт у файл
cat <<EOF | sudo tee "$GROOVY_SCRIPT_PATH" > /dev/null
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*

println("[INIT] Починаємо додавання SSH credentials...")

def instance = Jenkins.instance
if (instance == null) {
    println("❌ Помилка: неможливо отримати інстанс Jenkins")
    return
}

def credentialsStore = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()

def credentialId = "$CREDENTIAL_ID"
def existingCred = credentialsStore.getCredentials(Domain.global()).find { it.id == credentialId }
if (existingCred) {
    println("🔄 Credentials '\${credentialId}' вже існують. Видаляємо для оновлення...")
    credentialsStore.removeCredentials(Domain.global(), existingCred)
}

// 🌍 Створюємо Global SSH Username with Private Key
def sshKey = new BasicSSHUserPrivateKey(
    CredentialsScope.GLOBAL,
    credentialId,
    "jenkins",
    new BasicSSHUserPrivateKey.DirectEntryPrivateKeySource("""$SSH_PRIVATE_KEY"""),
    "",
    "Автоматично створені Global SSH credentials"
)

credentialsStore.addCredentials(Domain.global(), sshKey)
instance.save()

println("✅ Global SSH credentials '\${credentialId}' додано успішно!")
EOF

echo "✅ Groovy-скрипт для додавання SSH-ключа створено: $GROOVY_SCRIPT_PATH"

echo "🔹 Публічний ключ (додай його на сервер або GitHub!):"
echo "$SSH_PUBLIC_KEY"

# 🔄 Перезапускаємо Jenkins для застосування змін
echo "🚀 Перезапускаємо Jenkins..."
sudo systemctl restart jenkins
echo "✅ Jenkins перезапущено!"
