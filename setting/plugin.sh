#!/bin/bash

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="1"
CLI_JAR="jenkins_files/jenkins-cli.jar"

# Завантаження jenkins-cli.jar, якщо його немає
if [ ! -f "$CLI_JAR" ]; then
    echo "🔄 Завантаження jenkins-cli.jar..."
    curl -sSL "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" -o "$CLI_JAR"
    chmod +x "$CLI_JAR"
fi

plugins=(
    "cloudbees-folder"
    "custom-markup-formatter"
    "build-timeout"
    "credentials-binding"
    "timestamper"
    "ws-cleanup"
    "ant"
    "gradle"
    "workflow-aggregator"
    "github-branch-source"
    "github-api"
    "pipeline-github-lib"
    "pipeline-graph-view"
    "git"
    "ssh-slaves"
    "matrix-auth"
    "pam-auth"
    "ldap"
    "email-ext"
    "mailer"
    "dark-theme"
    "workflow-job"
    "workflow-cps"
)

for plugin in "${plugins[@]}"; do
    echo "Installing $plugin..."
    java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" install-plugin "$plugin"
    if [[ $? -ne 0 ]]; then
        echo "❌ Не вдалося встановити $plugin. Пропускаємо..."
    else
      echo "✅ Плагін $plugin встановлено"
    fi
done

echo "🔄 Перезапуск Jenkins..."
sudo systemctl restart jenkins
echo "✅ Jenkins перезапущено!"

# Запускаємо cred.sh
bash setting/cred.sh
