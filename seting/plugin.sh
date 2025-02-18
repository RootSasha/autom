#!/bin/bash

JENKINS_URL="http://192.168.0.113:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="1"  # Увага: краще використовувати API токен

# Download jenkins-cli.jar if it doesn't exist
if [ ! -f "jenkins-cli.jar" ]; then
  echo "Downloading jenkins-cli.jar..."
  wget "${JENKINS_URL}/jnlpJars/jenkins-cli.jar"
  if [[ $? -ne 0 ]]; then
    echo "Failed to download jenkins-cli.jar. Check Jenkins URL."
    exit 1
  fi
fi

plugins=(
    "cloudbees-folder"
    "custom-markup-formatter"  # Замінено "owasp-markup-formatter"
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
)

for plugin in "${plugins[@]}"; do
    echo "Installing $plugin..."
    java -jar jenkins-cli.jar -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" install-plugin "$plugin"
    if [[ $? -ne 0 ]]; then
        echo "Failed to install $plugin. Skipping..."
    fi
done

sudo systemctl restart jenkins

echo "Jenkins restart initiated."

echo "Create credentials"
bash seting/cred.sh
