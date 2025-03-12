#!/bin/bash

JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASSWORD="1"
CREDENTIAL_ID="ssh-key-jenkins"
JOB_DIR="jenkins_jobs"
mkdir -p "$JOB_DIR"

CLI_JAR="jenkins_files/jenkins-cli.jar"

# Завантаження jenkins-cli.jar, якщо його немає
if [ ! -f "$CLI_JAR" ]; then
    echo "🔄 Завантаження jenkins-cli.jar..."
    curl -sSL "${JENKINS_URL}/jnlpJars/jenkins-cli.jar" -o "$CLI_JAR"
    chmod +x "$CLI_JAR"
fi

declare -A pipelines=(
    ["grafana-monitoring"]="git@github.com:RootSasha/grafana.git"
    ["monitoring-site"]="git@github.com:RootSasha/diplome-site.git"
)

for job in "${!pipelines[@]}"; do
    REPO_URL="${pipelines[$job]}"
    JOB_XML="$JOB_DIR/$job.xml"

    echo "🚀 Створюємо пайплайн: $job (джерело: $REPO_URL)..."

    cat <<EOF > "$JOB_XML"
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

    java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" create-job "$job" < "$JOB_XML"

    if [[ $? -eq 0 ]]; then
        echo "✅ $job створено успішно!"
    else
        echo "❌ Помилка створення $job"
    fi

    java -jar "$CLI_JAR" -s "$JENKINS_URL" -auth "$JENKINS_USER:$JENKINS_PASSWORD" build "$job"
done

echo "🎉 Всі пайплайни створено та запущено!"
