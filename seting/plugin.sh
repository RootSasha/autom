#!/bin/bash

JENKINS_URL="http://192.168.0.113:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="1"  # Увага: краще використовувати API токен

plugins=(
    "cloudbees-folder"
    "owasp-markup-formatter" # Correct name
    "build-timeout"
    "credentials-binding"  # Correct name (was credentials-binding-plugin)
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
        echo "Failed to install $plugin. Check Jenkins logs for details."
    fi
done

sudo systemctl restart jenkins
