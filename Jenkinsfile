// Declarative pipeline for the Task API.
//
//   Checkout -> Test -> SonarQube -> Quality Gate -> Build image -> Trivy scan
//            -> Push -> Deploy staging (smoke test + auto rollback) -> Approve -> Deploy production
//
// Only the `main` branch pushes images and deploys.

pipeline {
    agent any

    options {
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    environment {
        REGISTRY   = 'ghcr.io/mohd-21'
        IMAGE_NAME = 'task-api'
        NETWORK    = 'cicd'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    def sha = sh(returnStdout: true, script: 'git rev-parse --short=7 HEAD').trim()
                    env.IMAGE_TAG  = "${env.BUILD_NUMBER}-${sha}"
                    env.IMAGE_FULL = "${env.REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                }
                echo "Building ${env.IMAGE_FULL}"
            }
        }

        stage('Test') {
            steps {
                // The Dockerfile "test" stage runs pytest; a failing test fails the build here.
                sh 'docker build --target test -t ${IMAGE_NAME}:test .'
                // Copy the reports out of the image for SonarQube and the Jenkins build page.
                sh '''
                    id=$(docker create ${IMAGE_NAME}:test)
                    docker cp "$id:/app/coverage.xml" coverage.xml
                    docker cp "$id:/app/junit.xml" junit.xml
                    docker rm "$id" > /dev/null
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'junit.xml'
                    archiveArtifacts artifacts: 'coverage.xml', allowEmptyArchive: true
                }
            }
        }

        stage('SonarQube analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    // Run the scanner container with this workspace mounted from the Jenkins container.
                    sh '''
                        docker run --rm \
                          --volumes-from jenkins -w "$WORKSPACE" \
                          --network ${NETWORK} \
                          -e SONAR_HOST_URL -e SONAR_TOKEN="$SONAR_AUTH_TOKEN" \
                          sonarsource/sonar-scanner-cli:latest
                    '''
                }
            }
        }

        stage('Quality Gate') {
            steps {
                // SonarQube calls back through a webhook (see scripts/bootstrap-sonarqube.sh).
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build image') {
            steps {
                sh 'docker build --target runtime --build-arg APP_VERSION=${IMAGE_TAG} -t ${IMAGE_FULL} .'
            }
        }

        stage('Trivy scan') {
            steps {
                // Fails the build on fixable HIGH or CRITICAL vulnerabilities.
                sh '''
                    docker run --rm \
                      -v /var/run/docker.sock:/var/run/docker.sock \
                      aquasec/trivy:latest image \
                      --severity CRITICAL,HIGH --ignore-unfixed --exit-code 1 \
                      ${IMAGE_FULL}
                '''
            }
        }

        stage('Push image') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(credentialsId: 'registry-creds',
                                                  usernameVariable: 'REG_USER',
                                                  passwordVariable: 'REG_PASS')]) {
                    sh '''
                        echo "$REG_PASS" | docker login ghcr.io -u "$REG_USER" --password-stdin
                        docker push ${IMAGE_FULL}
                        docker logout ghcr.io
                    '''
                }
            }
        }

        stage('Deploy to staging') {
            when { branch 'main' }
            steps {
                // Starts the container, runs a smoke test, rolls back to the previous image on failure.
                sh 'scripts/deploy.sh task-api-staging 8081 ${IMAGE_FULL}'
            }
        }

        stage('Approve production') {
            when { branch 'main' }
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    input message: "Deploy ${env.IMAGE_TAG} to production?", ok: 'Deploy'
                }
            }
        }

        stage('Deploy to production') {
            when { branch 'main' }
            steps {
                sh 'scripts/deploy.sh task-api-prod 8082 ${IMAGE_FULL}'
            }
        }
    }

    post {
        always {
            sh 'docker image prune -f || true'
            cleanWs()
        }
        success {
            echo "Pipeline finished: ${env.IMAGE_FULL}"
        }
        failure {
            echo "Pipeline FAILED at build ${env.BUILD_NUMBER}. Check the stage that turned red."
        }
    }
}
