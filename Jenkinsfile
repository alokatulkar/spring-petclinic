pipeline {
    agent any

    environment {
        AWS_REGION = "ap-south-1"
        EKS_CLUSTER = "ekscluster"
        DOCKER_IMAGE = "alokatulkar/petclinic"
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    stages {

        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                echo "Building Docker Image..."
                docker build -t $DOCKER_IMAGE:$IMAGE_TAG .
                '''
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
                    echo "Logging into DockerHub..."
                    echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                    '''
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                sh '''
                echo "Pushing Docker Image..."
                docker push $DOCKER_IMAGE:$IMAGE_TAG
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    sh '''
                    echo "Updating kubeconfig..."
                    aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER

                    echo "Updating image tag in Kubernetes YAML..."
                    sed -i "s|IMAGE_TAG|$IMAGE_TAG|g" k8s/petclinic.yml

                    echo "Deploying to EKS..."
                    kubectl apply -f k8s/db.yml
                    kubectl apply -f k8s/petclinic.yml

                    echo "Verifying deployment..."
                    kubectl get pods
                    kubectl get svc
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "✅ Deployment successful!"
        }
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}