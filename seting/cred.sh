#!/bin/bash

GITHUB_TOKEN="you_token"
SSH_KEY_PATH="/root/.ssh/id_ed25519"
GITHUB_EMAIL="sashamankovsky2019@gmail.com"
CREDENTIAL_ID="ssh-key-jenkins"
GROOVY_SCRIPT_PATH="/var/lib/jenkins/init.groovy.d/add-ssh-credentials.groovy"

# Перевіряємо, чи існує SSH-ключ, і створюємо його, якщо ні
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    echo " Генеруємо новий SSH-ключ..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -C "$GITHUB_EMAIL" -N "" -q
    echo "✅ Новий SSH-ключ створено!"
else
    echo " SSH-ключ вже існує, використовуємо його."
fi

# Читаємо приватний та публічний ключ
SSH_PRIVATE_KEY=$(cat "$SSH_KEY_PATH")
SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")

# Записуємо SSH-ключ у файл для подальшого використання
PRIVATE_KEY_FILE="/root/jenkins_ssh_key.txt"
echo "$SSH_PRIVATE_KEY" | sudo tee "$PRIVATE_KEY_FILE" > /dev/null
sudo chmod 600 "$PRIVATE_KEY_FILE"

# Записуємо Groovy-скрипт у файл
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
    println(" Credentials '\${credentialId}' вже існують. Видаляємо для оновлення...")
    credentialsStore.removeCredentials(Domain.global(), existingCred)
}

// Створюємо Global SSH Username with Private Key
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

echo " Публічний ключ (додай його на сервер або GitHub!):"
echo "$SSH_PUBLIC_KEY"

sudo -u jenkins mkdir -p /var/lib/jenkins/.ssh
sudo chmod 700 /var/lib/jenkins/.ssh
sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh

echo " Додаємо GitHub до known_hosts..."

# Додаємо ключ GitHub у known_hosts (без підтвердження)
sudo -u jenkins ssh-keyscan -H github.com | sudo tee /var/lib/jenkins/.ssh/known_hosts > /dev/null

# Встановлюємо правильні права на файл
sudo chmod 600 /var/lib/jenkins/.ssh/known_hosts
sudo chown jenkins:jenkins /var/lib/jenkins/.ssh/known_hosts

# Даємо дозволи у файлі visudo
echo "jenkins ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

# Даймо права докеру запускати pipeline
sudo usermod -aG docker jenkins

# Додавання публічного ключа до GitHub
echo " Додаємо публічний ключ до GitHub..."

# Перевірка, чи встановлено GitHub CLI (gh)
if ! command -v gh &> /dev/null
then
  echo "❌ GitHub CLI (gh) не встановлено. Будь ласка, встановіть його."
  exit 1
fi

# Авторизація GitHub CLI
echo "Авторизація GitHub CLI..."
echo "$GITHUB_TOKEN" | gh auth login --with-token

# Додавання публічного ключа до GitHub
gh ssh-key add "$SSH_KEY_PATH.pub" -t "Jenkins SSH Key"

echo "✅ Публічний ключ успішно додано до GitHub!"
