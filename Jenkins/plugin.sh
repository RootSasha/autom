#!/bin/bash

source config.sh

plugins=(
    "cloudbees-folder"
    "build-timeout"
    "credentials-binding"
    "timestamper"
    "ws-cleanup"
    "gradle"
    "workflow-aggregator"
    "github-branch-source"
    "git"
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

echo "Перезапуск Jenkins..."
sudo systemctl restart jenkins
echo "✅ Jenkins перезапущено!"
