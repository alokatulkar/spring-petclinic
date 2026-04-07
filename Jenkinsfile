pipeline {
    agent any

    environment {
        AWS_REGION = "ap-south-1"
        EKS_CLUSTER = "ekscluster"
        DOCKER_IMAGE = "yourdockerhub/petclinic"
        IMAGE_TAG = "${BUILD_NUMBER}"
        JAVA_HOME = "/usr/lib/jvm/java-21-openjdk-amd64"
        PATH = "${JAVA_HOME}/bin:${env.PATH}"
    }

    tools {
        maven 'Maven'
    }

    stages {

        stage('Debug Java & Maven') {
            steps {
                sh '''
                echo "===== JAVA VERSION ====="
                java -version

                echo "===== MAVEN VERSION ====="
                mvn -version
                '''
            }
        }

        stage('Build Application') {
            steps {
                sh 'mvn clean package -DskipTests'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $DOCKER_IMAGE:$IMAGE_TAG .'
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                    echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                    '''
                }
            }
        }

        stage('Push Image') {
            steps {
                sh 'docker push $DOCKER_IMAGE:$IMAGE_TAG'
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    sh '''
                    aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER

                    sed -i "s|IMAGE_TAG|$IMAGE_TAG|g" k8s/petclinic.yml

                    kubectl apply -f k8s/db.yml
                    kubectl apply -f k8s/petclinic.yml
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Deployment successful 🚀"
        }
        failure {
            echo "Pipeline failed ❌"
        }
    }
}