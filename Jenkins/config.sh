#!/bin/bash

JENKINS_USER="admin"

SSH_KEY_PATH="/root/.ssh/id_ed25519"
CREDENTIAL_ID="ssh-key-jenkins"

DOCKERHUB_USER="sasha22mk"

BUCKET_NAME="beckup-site"
AWS_REGION="eu-north-1"

# Jenkins файли
CLI_JAR="jenkins_files/jenkins-cli.jar"
JOB_DIR="jenkins_jobs"
