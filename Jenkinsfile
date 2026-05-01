pipeline {
    agent any

    environment {
        AWS_REGION = "ap-south-1"
        EKS_CLUSTER = "ekscluster"
        ECR_REPO = "612915905322.dkr.ecr.ap-south-1.amazonaws.com/petclinic"
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
                docker build -t $ECR_REPO:$IMAGE_TAG .
                '''
            }
        }

        stage('Login to ECR') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-creds'
                ]]) {
                    sh '''
                    echo "Logging into ECR..."
                    aws ecr get-login-password --region $AWS_REGION | \
                    docker login --username AWS --password-stdin $ECR_REPO
                    '''
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                sh '''
                echo "Pushing Docker Image to ECR..."
                docker push $ECR_REPO:$IMAGE_TAG
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