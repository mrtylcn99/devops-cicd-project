#!/bin/bash
# DevOps CI/CD Project - Infrastructure Cleanup Script
# Usage: ./destroy.sh [environment]
# Example: ./destroy.sh dev

set -e

if [ -z "$1" ]; then
    echo "ERROR: Environment parameter required!"
    echo ""
    echo "Usage: ./destroy.sh [environment]"
    echo "Example: ./destroy.sh dev"
    echo ""
    echo "Available environments: dev, staging, prod"
    exit 1
fi

ENV=$1

echo "========================================"
echo " DevOps CI/CD - Cleanup Script"
echo "========================================"
echo ""
echo "Environment: $ENV"
echo ""
echo "WARNING: This will delete ALL resources in $ENV environment!"
echo "- EKS Cluster"
echo "- EC2 Instances"
echo "- Load Balancer"
echo "- ECR Repository"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

echo ""
echo "[1/3] Deleting Kubernetes resources..."
echo "========================================"
if kubectl delete namespace $ENV --force --grace-period=0 2>/dev/null; then
    echo "Kubernetes namespace $ENV deleted successfully"
else
    echo "Warning: Kubernetes namespace deletion failed or already deleted"
fi

echo ""
echo "[2/3] Waiting for LoadBalancer to be deleted..."
echo "========================================"
echo "This may take 2-3 minutes..."
sleep 180

echo ""
echo "[3/3] Destroying Terraform infrastructure..."
echo "========================================"
cd terraform
terraform destroy -var-file="${ENV}.tfvars" -auto-approve

if [ $? -eq 0 ]; then
    cd ..
    echo ""
    echo "========================================"
    echo " CLEANUP COMPLETED SUCCESSFULLY!"
    echo "========================================"
    echo ""
    echo "Environment $ENV has been destroyed."
    echo ""
    echo "IMPORTANT: Verify in AWS Console:"
    echo "- EC2 Instances are terminated"
    echo "- Load Balancers are deleted"
    echo "- EKS Cluster is gone"
    echo ""
    echo "Check your AWS bill in 24 hours to confirm zero usage."
else
    echo ""
    echo "ERROR: Terraform destroy failed!"
    echo "Please check the error messages above."
    echo "You may need to manually delete resources from AWS Console."
    exit 1
fi
