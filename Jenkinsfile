pipeline {
  agent any

  environment {
    DOCKERHUB_CRED = 'dockerhub-creds'
    SSH_CRED = 'ssh-app-server'
    APP_SERVER = 'ubuntu@13.60.220.253'
    DOCKERHUB_USER = 'jegadeeshanjeggy'
    IMAGE_NAME = 'dev-app'
  }

  stages {

    stage('Build & Push Docker Image') {
      steps {
        script {
          def sha = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def envType = (env.BRANCH_NAME == 'dev') ? 'dev' : 'prod'

          def tagName = "${DOCKERHUB_USER}/${IMAGE_NAME}:${envType}-${sha}"
          def latestName = "${DOCKERHUB_USER}/${IMAGE_NAME}:${envType}"

          sh "docker build -t ${tagName} -t ${latestName} ."

          withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CRED}", usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh "echo $DH_PASS | docker login --username $DH_USER --password-stdin"
          }

          sh "docker push ${tagName}"
          sh "docker push ${latestName}"

          writeFile file: 'imagename.txt', text: tagName
          archiveArtifacts artifacts: 'imagename.txt'
        }
      }
    }

    stage('Deploy to App Server') {
      steps {
        script {
          def image = readFile('imagename.txt').trim()

          sshagent(credentials: [SSH_CRED]) {
            sh """
            ssh -o StrictHostKeyChecking=no ${APP_SERVER} 'bash -s' << 'EOF'
              docker pull ${image}
              sed -i "s|image:.*|image: ${image}|g" /opt/production-app/docker-compose.yml
              cd /opt/production-app
              docker compose up -d --remove-orphans
            EOF
            """
          }
        }
      }
    }
  }

  post {
    success {
      echo "Pipeline completed successfully."
    }
    failure {
      echo "Pipeline failed!"
    }
  }
}

