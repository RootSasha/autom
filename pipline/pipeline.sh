#!/bin/bash

JENKINS_URL="http://192.168.0.113:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="1"  # 🔹 Краще використовувати API-токен
CREDENTIAL_ID="ssh-key-jenkins"  # 🔹 Використовуємо правильний ID SSH-ключа

CLI_JAR="jenkins-cli.jar"

# 🔹 Налаштування pipeline'ів
declare -A pipelines=(
    ["grafana-monitoring"]="git@github.com:RootSasha/grafana.git"
    ["monitoring-site"]="git@github.com:RootSasha/diplome-site.git"
)

# 🔹 Створюємо pipeline для кожного репозиторію
for job in "${!pipelines[@]}"; do
    REPO_URL="${pipelines[$job]}"

    echo "🚀 Створюємо пайплайн: $job (джерело: $REPO_URL)..."

    cat <<EOF > "$job.xml"
<flow-definition plugin="workflow-job">
    <actions/>
    <description>Pipeline для $job</description>
    <keepDependencies>false</keepDependencies>
    <properties/>
    <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition">
        <scm class="hudson.plugins.git.GitSCM">
            <configVersion>2</configVersion>
            <userRemoteConfigs>
                <hudson.plugins.git.UserRemoteConfig>
                    <url>$REPO_URL</url>
                    <credentialsId>$CREDENTIAL_ID</credentialsId>  <!-- 🔹 Використовуємо заданий ID SSH-ключа -->
                </hudson.plugins.git.UserRemoteConfig>
            </userRemoteConfigs>
            <branches>
                <hudson.plugins.git.BranchSpec>
                    <name>*/main</name>  <!-- 🔹 Використовуйте потрібну гілку -->
                </hudson.plugins.git.BranchSpec>
            </branches>
        </scm>
        <scriptPath>Jenkinsfile</scriptPath>  <!-- 🔹 Jenkinsfile має бути у репозиторії -->
        <sandbox>true</sandbox>
    </definition>
    <triggers/>
</flow-definition>
EOF

    # 🔹 Створюємо pipeline job у Jenkins
    java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" create-job "$job" < "$job.xml"

    if [[ $? -eq 0 ]]; then
        echo "✅ $job створено успішно!"
    else
        echo "❌ Помилка створення $job"
    fi

    # 🔹 Запускаємо pipeline після створення
    java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" build "$job"
done

echo "🎉 Всі пайплайни створено та запущено!"
