#!/bin/bash

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
TOKEN_FILE="/root/jenkins_api_token.txt"

# Отримуємо API-токен із файлу
if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "❌ Помилка: Файл із API-токеном не знайдено!"
    exit 1
fi

JENKINS_API_TOKEN=$(cat "$TOKEN_FILE")

# Функція для створення Jenkins pipeline job
create_pipeline_job() {
    local repo_url=$1
    local job_name=$2

    echo "🛠 Створення Jenkins pipeline job '$job_name'..."
    curl -u $JENKINS_USER:$JENKINS_API_TOKEN -X POST -H "Content-Type: application/xml" \
         -d "<flow-definition>
               <description>Pipeline для $job_name з GitHub репозиторію</description>
               <definition class=\"org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition\">
                 <script>
                   pipeline {
                     agent any
                     stages {
                       stage('Checkout') {
                         steps {
                           git url: '$repo_url', branch: 'main'
                         }
                       }
                       stage('Build') {
                         steps {
                           sh 'make'
                         }
                       }
                       stage('Test') {
                         steps {
                           sh 'make test'
                         }
                       }
                     }
                   }
                 </script>
               </definition>
             </flow-definition>" \
         "$JENKINS_URL/createItem?name=$job_name"
    
    echo "✔️ Jenkins job '$job_name' створено."
}

# Основна логіка
echo "🚀 Запуск створення Jenkins pipeline jobs..."

create_pipeline_job "git@github.com:RootSasha/grafana.git" "grafana-pipeline-job"
create_pipeline_job "git@github.com:RootSasha/test.git" "test-pipeline-job"

echo "✅ Усі Jenkins pipelines створено!"
