pipeline {
  agent any

  environment {
    DOCKERHUB_CRED = 'dockerhub-creds'       // DockerHub username/password (Jenkins credential)
    SSH_CRED = 'ssh-app-server'              // SSH private key used to login to App Server
    APP_SERVER = 'ubuntu@13.60.220.253'      // Your app server IP
    DOCKERHUB_USER = 'jegadeeshanjeggy'      // Your DockerHub username
    IMAGE_NAME = 'dev-app'                   // Your Docker image name
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build & Push Docker Image') {
      steps {
        script {

          // get short Git commit SHA
          def sha = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()

          // Determine environment (dev branch or master -> prod)
          def envType = (env.BRANCH_NAME == 'dev') ? 'dev' : 'prod'

          // Build tags:
          def tagName = "${DOCKERHUB_USER}/${IMAGE_NAME}:${envType}-${sha}"
          def latestName = "${DOCKERHUB_USER}/${IMAGE_NAME}:${envType}"

          echo "Building Docker image: ${tagName}"
          sh "docker build -t ${tagName} -t ${latestName} ."

          // Login to DockerHub
          echo "Logging in to DockerHub"
          withCredentials([usernamePassword(credentialsId: "${DOCKERHUB_CRED}", usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh "echo $DH_PASS | docker login --username $DH_USER --password-stdin"
          }

          // Push both tags
          sh "docker push ${tagName}"
          sh "docker push ${latestName}"

          // Save tagName for deploy stage
          writeFile file: 'imagename.txt', text: tagName
          archiveArtifacts artifacts: 'imagename.txt'
        }
      }
    }

    stage('Deploy to App Server') {
      when {
        anyOf {
          branch 'dev'
          branch 'master'
        }
      }
      steps {
        script {
          def image = readFile('imagename.txt').trim()
          echo "Deploying image ${image} to ${APP_SERVER}"

          sshagent(credentials: [SSH_CRED]) {
            sh """
            ssh -o StrictHostKeyChecking=no ${APP_SERVER} 'bash -s' << 'EOF'
              set -e
              echo "Pulling ${image} on app server..."
              docker pull ${image}

              echo "Updating /opt/production-app/docker-compose.yml ..."
              sed -i "s|image:.*|image: ${image}|g" /opt/production-app/docker-compose.yml || true

              echo "Restarting container..."
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

