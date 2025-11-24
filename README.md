**Guvi Project 3**

Link : https://docs.google.com/document/d/11kbFude1yL9C3r--VX-HM_bZYuWNusVI1P_mITJTDc4/edit?tab=t.0

**Architecture**

GitHub → Jenkins → Docker Build → DockerHub → EC2 App Server → Monitoring (Uptime Kuma)

**Project Structure**

<img width="413" height="277" alt="image" src="https://github.com/user-attachments/assets/0c776027-43b5-4a14-a67c-f9a3805b0b89" />

**Infrastructure**
Use 2 EC2 servers:
1. Server 1 (App Server) — t3.micro → Runs Docker + your React app container.
2. Server 2 (CI/CD + Monitoring) — t3.small → Runs Jenkins, Docker (build agent), and Uptime Kuma for monitoring.


**Server 1 (App Server)**

1. Clone Project:

git clone https://github.com/Jegadeeshanp/GuviProject-devops-build.git

cd GuviProject-devops-build


<img width="256" height="129" alt="image" src="https://github.com/user-attachments/assets/eb0c80c0-b41f-4862-9fc9-cf9825ae4852" />

2. Create .gitignore and .dockerignore
3. Create Dockerfile
4. Create nginx.conf
5. Create docker-compose.yml
6. Test is locally
   docker compose up --build
   
<img width="940" height="480" alt="image" src="https://github.com/user-attachments/assets/4b5337d3-3df8-4d3e-88c1-781edfc07c3e" />


Create build.sh & deploy.sh

build.sh : Script builds the React app → builds a Docker image → tags it → logs in → pushes it to Docker Hub automatically

deploy.sh : Script pulls the specified Docker image from Docker Hub → updates or creates the docker-compose deployment → restarts the container with the new image → and shows the running status automatically.

<img width="940" height="436" alt="image" src="https://github.com/user-attachments/assets/393373e9-7921-4919-bdad-7a452a220cff" />

<img width="940" height="465" alt="image" src="https://github.com/user-attachments/assets/3536d7bc-8a55-4282-aef6-a5851b6aed7c" />

<img width="827" height="251" alt="image" src="https://github.com/user-attachments/assets/7a4d164c-0b27-4413-9ce7-93954380e261" />

<img width="632" height="450" alt="image" src="https://github.com/user-attachments/assets/82b5b34b-57e1-40bf-9d0b-06b2155d786b" />


**Server 2 (Jenkins + Monitoring Server)**

**Install Docker**

sudo apt update

sudo apt -y upgrade


curl -fsSL https://get.docker.com -o get-docker.sh

sudo sh get-docker.sh


sudo usermod -aG docker ubuntu

newgrp docker


**Install Jenkins**


sudo apt install -y openjdk-11-jdk


curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
  /usr/share/keyrings/jenkins-keyring.asc > /dev/null
  

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
  

sudo apt update

sudo apt install -y jenkins


sudo systemctl enable jenkins

sudo systemctl start jenkins




<img width="940" height="448" alt="image" src="https://github.com/user-attachments/assets/86ea793e-524a-4c80-84df-1171d8085626" />



**Install Uptime Kuma Script**

docker volume create uptime-kuma

docker run -d \

  --name uptime-kuma \
  
  -p 3001:3001 \
  
  -v uptime-kuma:/app/data \
  
  louislam/uptime-kuma:latest
  

<img width="940" height="416" alt="image" src="https://github.com/user-attachments/assets/db3d7e77-9ffb-4596-868b-08649f708452" />


**Jenkins job: Pipeline**

Create Jenkinsfile

pipeline {
  agent any

  environment {
    DOCKERHUB_CRED = 'dockerhub-creds'
    SSH_CRED       = 'ssh-app-server'
    APP_SERVER     = 'ubuntu@13.60.220.253'
    DOCKERHUB_USER = 'jegadeeshanjeggy'
    IMAGE_NAME     = 'dev-app'
  }

  stages {

    stage('Build & Push Docker Image') {
      steps {
        script {
          def sha = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          def envType = (env.BRANCH_NAME == 'dev') ? 'dev' : 'prod'

          def tagName   = "${DOCKERHUB_USER}/${IMAGE_NAME}:${envType}-${sha}"
          def latestTag = "${DOCKERHUB_USER}/${IMAGE_NAME}:${envType}"

          sh "docker build -t ${tagName} -t ${latestTag} ."

          withCredentials([usernamePassword(credentialsId: DOCKERHUB_CRED, usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh "echo $DH_PASS | docker login --username $DH_USER --password-stdin"
          }

          sh "docker push ${tagName}"
          sh "docker push ${latestTag}"

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
ssh -o StrictHostKeyChecking=no ${APP_SERVER} <<EOF
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


**Connect GitHub webhook to Jenkins**

In GitHub repo → Settings → Webhooks:

<img width="940" height="525" alt="image" src="https://github.com/user-attachments/assets/3d58aab7-ebc2-41ff-bcf3-a183d48f4fdf" />

**GIT Branches**

<img width="940" height="463" alt="image" src="https://github.com/user-attachments/assets/e61bbe17-e1c1-4acc-a2ce-1537fbd9be3f" />

<img width="940" height="464" alt="image" src="https://github.com/user-attachments/assets/a91e8f4a-a676-4cdb-a810-822af0dd2191" />



**Trigger build & Monitor**

Jenkins Success Build: 

Logs : https://github.com/Jegadeeshanp/GuviProject-devops-build/blob/main/GuviProject3_Success_Logs23.txt

<img width="940" height="451" alt="image" src="https://github.com/user-attachments/assets/ffe9bfdb-5c16-4658-81a4-240c1880c397" />

<img width="940" height="459" alt="image" src="https://github.com/user-attachments/assets/198ef350-665d-4515-a7b5-2fe19b870086" />

<img width="940" height="457" alt="image" src="https://github.com/user-attachments/assets/6cefc790-c24b-4693-98bf-4d366dca5b1b" />

<img width="940" height="479" alt="image" src="https://github.com/user-attachments/assets/fe105a84-ed7a-498c-aa59-de072b77f771" />

Uptime Kuma monitoring:

<img width="940" height="457" alt="image" src="https://github.com/user-attachments/assets/06456e9b-c9ff-4a25-b292-a323e46fcbb3" />








