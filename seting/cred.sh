#!/bin/bash

SSH_KEY_PATH="/root/.ssh/id_ed25519"
GITHUB_EMAIL="sashamankovsky2019@gmail.com"
CREDENTIAL_ID="ssh-key-jenkins"
GROOVY_SCRIPT_PATH="/var/lib/jenkins/init.groovy.d/add-ssh-credentials.groovy"
<<<<<<< HEAD
GITHUB_USERNAME="YourGitHubUsername"
GITHUB_TOKEN="YourGitHubToken"
=======
GITHUB_USERNAME="RootSasha"
GITHUB_TOKEN="you_token"
>>>>>>> c716eef (Initial commit)

# 🛠 Перевіряємо, чи існують SSH-ключі
if [[ -f "$SSH_KEY_PATH" && -f "$SSH_KEY_PATH.pub" ]]; then
    echo "✅ SSH-ключ вже існує! Ось ваш публічний ключ:"
    cat "$SSH_KEY_PATH.pub"
else
    echo "🔑 Генеруємо новий SSH-ключ..."
    ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -C "$GITHUB_EMAIL" -N "" -q
    echo "✅ Новий SSH-ключ створено!"
fi

# Читаємо приватний та публічний ключ
SSH_PRIVATE_KEY=$(cat "$SSH_KEY_PATH")
SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")

# 📌 Записуємо SSH-ключ у файл для подальшого використання
PRIVATE_KEY_FILE="/root/jenkins_ssh_key.txt"
echo "$SSH_PRIVATE_KEY" | sudo tee "$PRIVATE_KEY_FILE" > /dev/null
sudo chmod 600 "$PRIVATE_KEY_FILE"

# 🛠 Додаємо ключ на GitHub
GITHUB_API_URL="https://api.github.com/user/keys"
KEY_TITLE="Jenkins_AutoKey"

EXISTING_KEYS=$(curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" "$GITHUB_API_URL" | jq -r '.[].key')
if echo "$EXISTING_KEYS" | grep -q "$SSH_PUBLIC_KEY"; then
    echo "✅ SSH-ключ вже є на GitHub!"
else
    echo "🔗 Додаємо SSH-ключ на GitHub..."
    curl -s -u "$GITHUB_USERNAME:$GITHUB_TOKEN" -X POST -H "Content-Type: application/json" \
         -d "{\"title\": \"$KEY_TITLE\", \"key\": \"$SSH_PUBLIC_KEY\"}" "$GITHUB_API_URL"
    echo "✅ SSH-ключ успішно додано на GitHub!"
fi

# 📌 Записуємо Groovy-скрипт у файл
cat <<EOF | sudo tee "$GROOVY_SCRIPT_PATH" > /dev/null
import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*

def instance = Jenkins.instance
if (instance == null) {
    return
}

def credentialsStore = instance.getExtensionList('com.cloudbees.plugins.credentials.SystemCredentialsProvider')[0].getStore()
def credentialId = "$CREDENTIAL_ID"
def existingCred = credentialsStore.getCredentials(Domain.global()).find { it.id == credentialId }
if (existingCred) {
    credentialsStore.removeCredentials(Domain.global(), existingCred)
}

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
EOF

echo "✅ Groovy-скрипт для додавання SSH-ключа створено!"

# Додаємо GitHub до known_hosts
sudo -u jenkins mkdir -p /var/lib/jenkins/.ssh
sudo chmod 700 /var/lib/jenkins/.ssh
sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh
sudo -u jenkins ssh-keyscan -H github.com | sudo tee /var/lib/jenkins/.ssh/known_hosts > /dev/null
sudo chmod 600 /var/lib/jenkins/.ssh/known_hosts
sudo chown jenkins:jenkins /var/lib/jenkins/.ssh/known_hosts

# Дозволяємо jenkins виконувати sudo без пароля
sudo grep -q "^jenkins ALL=(ALL) NOPASSWD: ALL" /etc/sudoers || sudo sed -i '1s|^|jenkins ALL=(ALL) NOPASSWD: ALL\n|' /etc/sudoers

# Додаємо jenkins до групи docker
sudo usermod -aG docker jenkins

echo "🚀 Налаштування завершено!"
