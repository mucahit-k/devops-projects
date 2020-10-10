pipeline {
    agent {
        label 'master'
    }
    environment {
        APP_REPO_NAME="mucahit-k/phonebook-app"
        AWS_REGION="us-east-1"
        STACK_NAME="phonebook-${BUILD_NUMBER}"
        ECR_REGISTRY="331210975209.dkr.ecr.${AWS_REGION}.amazonaws.com"
        CFN_KEYPAIR="new-key"
        PATH=sh(script:"echo $PATH:/usr/local/bin", returnStdout:true).trim()
        GITHUB_REPO="https://github.com/mucahit-k/devops-projects.git#:projects/204-jenkins-pipeline-for-phonebook-app-on-docker-swarm"
        GIT_FILE_URL="https://raw.githubusercontent.com/mucahit-k/devops-projects/master/projects/204-jenkins-pipeline-for-phonebook-app-on-docker-swarm/"
    }
    stages {
        stage('creating ECR Repo') {
            steps {
                echo 'Creating ECR Repository'
                sh """
                aws ecr create-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --image-scanning-configuration scanOnPush=false \
                  --image-tag-mutability MUTABLE \
                  --region ${AWS_REGION}"""
            }
        }
        stage('building Docker image') {
            steps {
                echo 'Building app Docker image'
                sh "docker build --force-rm -t ${ECR_REGISTRY}/${APP_REPO_NAME}:latest ${GITHUB_REPO}"
                sh "docker image ls"
            }
        }
        stage('pushing Docker image to ECR Repo') {
            steps {
                echo 'Pushing images to ECR'
                sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                sh "docker push ${ECR_REGISTRY}/${APP_REPO_NAME}:latest"
            }
        }
        stage('creating infrastructure for the app') {
            steps {
                echo 'Creating Docker Swarm'
                sh "curl -o 'cfn-template.yml' -L ${GIT_FILE_URL}cfn-template.yml"
                sh "aws cloudformation create-stack --stack-name ${STACK_NAME} --region ${AWS_REGION} --template-body file://cfn-template.yml --parameters ParameterKey=KeyPairName,ParameterValue=${CFN_KEYPAIR} --capabilities CAPABILITY_IAM"
                script {
                    sleep(150)
                    while(true){
                        echo "Docker Grand Master is not UP and running yet. Will try to reach again after 10 seconds"
                        sleep(10)
                        ip = sh(script:'aws ec2 describe-instances --region ${AWS_REGION} --filters Name=tag:Name,Values="Docker Grand Master of ${STACK_NAME}" --query Reservations[*].Instances[*].[PublicIpAddress] --output text | sed "s/\\s*None\\s*//g"', returnStdout:true).trim()

                        if (ip.length() >= 7) {
                            echo "Docker Grand Master Public IP Address Found: $ip"
                            env.MASTER_INSTANCE_PUBLIC_IP = "$ip"
                            break
                        } 
                    }
                }
            }
        }
        stage('test the Viz App') {
            steps {
                echo "Testing if Docker Swarm is ready or not by checking the Viz App on Grand Master with Public IP:${MASTER_INSTANCE_PUBLIC_IP}:8080"
                script {
                    sleep(100)
                    while(true) {
                        try{
                            sh "curl -s ${MASTER_INSTANCE_PUBLIC_IP}:8080"
                            echo "Successfull connected to Viz App."
                            break
                        }
                        catch(Exception){
                            echo 'Could not connect to Viz App'
                            sleep(5)
                        }
                    }
                }
            }
        }
        stage('deploying the application') {
            environment {
                MASTER_INSTANCE_ID = sh(script:"aws ec2 describe-instances --region ${AWS_REGION} --filters Name=tag:Name,Values='Docker Grand Master of ${STACK_NAME}' --query Reservations[*].Instances[*].[InstanceId] --output text", returnStdout:true).trim()
            }
            steps {
                echo "Cloning and Deploying App on Swarm using Grand Master with Instance Id: ${MASTER_INSTANCE_ID}"
                sh "mssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no --region ${AWS_REGION} ${MASTER_INSTANCE_ID} curl -s --create-dirs -o '/home/ec2-user/phonebook/docker-compose.yml' -L ${GIT_FILE_URL}docker-compose.yml"
                sh "mssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no --region ${AWS_REGION} ${MASTER_INSTANCE_ID} curl -s --create-dirs -o '/home/ec2-user/phonebook/init.sql' -L ${GIT_FILE_URL}init.sql"
                sleep(10)
                sh "mssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no --region ${AWS_REGION} ${MASTER_INSTANCE_ID} docker stack deploy -c /home/ec2-user/phonebook/docker-compose.yml ${STACK_NAME}"
            }
        }
        stage('Test the application'){
            steps {
                echo 'Check if the application is ready or not'
                script {

                    while(true) {
                        try{
                            sh "curl -s ${MASTER_INSTANCE_PUBLIC_IP}"
                            echo "Phonebook App is successfully deployed."
                            break
                        }
                        catch(Exception){
                            echo 'Could not connect to Phonebook App'
                            sleep(5)
                        }
                    }
                }
            }
        }
    }
    post {
        always {
            echo 'Deleting all local images'
            sh "docker image prune -af"
        }
        failure {
            echo 'Deleting the image repository on ECR due to failure'
            sh """
                aws ecr delete-repository \
                  --repository-name ${APP_REPO_NAME} \
                  --force --region ${AWS_REGION}
                """
            echo 'Deleting the cloudformation stack due to failure'
            sh "aws cloudformation delete-stack --stack-name ${STACK_NAME} --region ${AWS_REGION}"
        }
    }
}