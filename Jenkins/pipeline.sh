#!/bin/bash

JENKINS_URL="http://16.16.217.80:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="1"
CREDENTIAL_ID="ssh-key-jenkins"
JOB_DIR="jenkins_jobs"
CLI_JAR="jenkins_files/jenkins-cli.jar"

mkdir -p "$JOB_DIR"

declare -A pipelines=(
    ["grafana-monitoring"]="git@github.com:RootSasha/grafana.git"
    ["monitoring-site"]="git@github.com:RootSasha/diplome-site.git"
)

# Перевірка, чи існує jenkins-cli.jar
if [[ ! -f "$CLI_JAR" ]]; then
    echo "❌ Помилка: Файл $CLI_JAR не знайдено. Завантаж його з Jenkins!"
    exit 1
fi

for job in "${!pipelines[@]}"; do
    REPO_URL="${pipelines[$job]}"
    JOB_XML="$JOB_DIR/$job.xml"

    echo "Створюємо пайплайн: $job (джерело: $REPO_URL)..."

    cat > "$JOB_XML" <<EOF
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
                    <credentialsId>$CREDENTIAL_ID</credentialsId>
                </hudson.plugins.git.UserRemoteConfig>
            </userRemoteConfigs>
            <branches>
                <hudson.plugins.git.BranchSpec>
                    <name>*/main</name>
                </hudson.plugins.git.BranchSpec>
            </branches>
        </scm>
        <scriptPath>Jenkinsfile</scriptPath>
        <sandbox>true</sandbox>
    </definition>
    <triggers/>
</flow-definition>
EOF

    # Створення або оновлення джоба
    java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" create-job "$job" < "$JOB_XML"

    if [[ $? -eq 0 ]]; then
        echo "✅ $job створено успішно!"
    else
        echo "❌ Помилка створення $job, пробуємо оновити..."
        java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" update-job "$job" < "$JOB_XML"
        if [[ $? -eq 0 ]]; then
            echo "✅ $job оновлено успішно!"
        else
            echo "❌ Помилка оновлення $job"
        fi
    fi
done

echo "✅ Всі пайплайни створено!"
