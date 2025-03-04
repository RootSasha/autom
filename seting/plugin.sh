#!/bin/bash

JENKINS_URL="http://192.168.0.113:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="1" # Будьте обережні, використовуючи пароль у скрипті

# Download jenkins-cli.jar if it doesn't exist
if [ ! -f "jenkins-cli.jar" ]; then
    echo "Downloading jenkins-cli.jar..."
    curl -sSL "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" -o jenkins-cli.jar
    if [[ $? -ne 0 ]]; then
        echo "❌ Помилка: Не вдалося завантажити jenkins-cli.jar. Перевірте URL Jenkins."
        exit 1
    fi
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
    "workflow-job" # Додано workflow-job
    "workflow-cps" # Додано workflow-cps
)

for plugin in "${plugins[@]}"; do
    echo "Installing $plugin..."
    java -jar jenkins-cli.jar -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" install-plugin "$plugin"
    if [[ $? -ne 0 ]]; then
        echo "❌ Не вдалося встановити $plugin. Пропускаємо..."
    else
      echo "✅ Плагін $plugin встановлено"
    fi
done

echo " Перезапуск Jenkins..."
sudo systemctl restart jenkins
echo "✅ Jenkins перезапущено!"

# Запускаємо cred.sh
bash seting/cred.sh
