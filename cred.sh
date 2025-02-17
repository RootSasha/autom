#!/bin/bash

SSH_KEY_PATH="/root/.ssh/id_ed25519"
GITHUB_EMAIL="xxxxxxxxxxxxx@gmail.com"

# 🔍 Перевіряємо, чи існує SSH-ключ
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo "🔑 SSH-ключ не знайдено, створюємо новий..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -C "$GITHUB_EMAIL" -N "" -q
    echo "✅ Новий SSH-ключ створено!"
else
    echo "✅ SSH-ключ вже існує!"
fi

# Читаємо приватний та публічний ключ
SSH_PRIVATE_KEY=$(cat "$SSH_KEY_PATH")
SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")

# 📌 Записуємо Groovy-скрипт у файл
cat <<EOF > /var/lib/jenkins/init.groovy.d/add-ssh-credentials.groovy
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

def credentialId = "ssh-key-jenkins"
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

echo "✅ Groovy-скрипт для додавання SSH-ключа створено: /var/lib/jenkins/init.groovy.d/add-ssh-credentials.groovy"

echo "🔹 Публічний ключ (додай його на сервер або GitHub!):"
echo "$SSH_PUBLIC_KEY"
