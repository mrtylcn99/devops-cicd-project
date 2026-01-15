#!/bin/bash
# DevOps CI/CD Project - Quick Environment Setup
# Usage: ./deploy-env.sh [environment]
# Example: ./deploy-env.sh staging

set -e

if [ -z "$1" ]; then
    echo "ERROR: Environment parameter required!"
    echo ""
    echo "Usage: ./deploy-env.sh [environment]"
    echo "Example: ./deploy-env.sh staging"
    echo ""
    echo "Available environments: dev, staging, prod"
    exit 1
fi

ENV=$1

echo "========================================"
echo " DevOps CI/CD - Environment Setup"
echo "========================================"
echo ""
echo "Environment: $ENV"
echo ""
echo "This script will:"
echo "1. Deploy Terraform infrastructure"
echo "2. Configure kubectl"
echo "3. Create Kubernetes namespaces"
echo ""
echo "Estimated time: 15-20 minutes"
echo "Estimated cost: ~\$0.13/hour"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

echo ""
echo "[1/4] Deploying Terraform infrastructure..."
echo "========================================"
cd terraform
terraform init
terraform apply -var-file="${ENV}.tfvars" -auto-approve

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Terraform deployment failed!"
    exit 1
fi

echo ""
echo "[2/4] Configuring kubectl..."
echo "========================================"
CLUSTER_NAME=$(terraform output -raw cluster_name)
aws eks update-kubeconfig --region eu-central-1 --name $CLUSTER_NAME

echo ""
echo "[3/4] Creating Kubernetes namespaces..."
echo "========================================"
cd ..
kubectl apply -f k8s/namespace.yaml

echo ""
echo "[4/4] Waiting for nodes to be ready..."
echo "========================================"
sleep 30
kubectl get nodes

echo ""
echo "========================================"
echo " SETUP COMPLETED SUCCESSFULLY!"
echo "========================================"
echo ""
echo "Environment: $ENV"
echo "Cluster: $CLUSTER_NAME"
echo ""
echo "Next steps:"
echo "1. Push code to trigger deployment:"
echo "   git push origin $ENV"
echo ""
echo "2. Monitor deployment:"
echo "   kubectl get pods -n $ENV --watch"
echo ""
echo "3. Get application URL:"
echo "   kubectl get svc devops-app-service -n $ENV"
echo ""
echo "WARNING: Don't forget to destroy when done!"
echo "Command: ./destroy.sh $ENV"
