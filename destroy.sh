#!/bin/bash
# DevOps CI/CD Project - Infrastructure Cleanup Script
# Usage: ./destroy.sh [environment]
# Example: ./destroy.sh dev
# Or: ./destroy.sh (destroys all 3 environments)

set -e

destroy_single_env() {
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
    if [ ! -z "$2" ]; then
        read -p "Press Enter to continue or Ctrl+C to cancel..."
    fi

    echo ""
    echo "[1/4] Deleting Kubernetes resources..."
    echo "========================================"
    if kubectl delete namespace $ENV --force --grace-period=0 2>/dev/null; then
        echo "Kubernetes namespace $ENV deleted successfully"
    else
        echo "Warning: Kubernetes namespace deletion failed or already deleted"
    fi

    echo ""
    echo "[2/4] Deleting LoadBalancers..."
    echo "========================================"
    echo "Finding and deleting LoadBalancers for $ENV environment..."

    # Get cluster name for this environment
    cd terraform
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "")
    cd ..

    # Delete all LoadBalancers (both classic ELB and ALB/NLB)
    for lb in $(aws elb describe-load-balancers --region eu-central-1 --query "LoadBalancerDescriptions[*].LoadBalancerName" --output text 2>/dev/null); do
        echo "Deleting LoadBalancer: $lb"
        aws elb delete-load-balancer --load-balancer-name $lb --region eu-central-1 2>/dev/null || true
    done

    for alb in $(aws elbv2 describe-load-balancers --region eu-central-1 --query "LoadBalancers[*].LoadBalancerArn" --output text 2>/dev/null); do
        echo "Deleting ALB/NLB: $alb"
        aws elbv2 delete-load-balancer --load-balancer-arn $alb --region eu-central-1 2>/dev/null || true
    done

    echo "Waiting for LoadBalancers to be fully deleted..."
    sleep 30

    echo ""
    echo "[3/4] Switching Terraform workspace..."
    echo "========================================"
    cd terraform
    terraform init

    # Switch to appropriate workspace
    if [ "$ENV" = "dev" ]; then
        echo "Selecting default workspace for dev..."
        terraform workspace select default 2>/dev/null
    else
        echo "Selecting $ENV workspace..."
        terraform workspace select $ENV 2>/dev/null
    fi

    echo ""
    echo "[4/4] Destroying Terraform infrastructure..."
    echo "========================================"
    terraform destroy -var-file="${ENV}.tfvars" -auto-approve

    if [ $? -ne 0 ]; then
        echo ""
        echo "ERROR: Terraform destroy failed!"
        echo "Please check the error messages above."
        echo "You may need to manually delete resources from AWS Console."
        cd ..
        exit 1
    fi

    cd ..

    echo ""
    echo "========================================"
    echo " CLEANUP COMPLETED SUCCESSFULLY!"
    echo "========================================"
    echo ""
    echo "Environment $ENV has been destroyed."
    echo ""
}

if [ -z "$1" ]; then
    echo "========================================"
    echo " DevOps CI/CD - Destroy ALL Environments"
    echo "========================================"
    echo ""
    echo "No environment specified. Will destroy ALL 3 environments:"
    echo "- Dev"
    echo "- Staging"
    echo "- Production"
    echo ""
    echo "WARNING: This will delete everything!"
    echo "This will take approximately 20-25 minutes"
    echo ""
    read -p "Press Enter to continue or Ctrl+C to cancel..."

    destroy_single_env dev
    destroy_single_env staging
    destroy_single_env prod

    echo ""
    echo "========================================"
    echo " ALL ENVIRONMENTS DESTROYED!"
    echo "========================================"
    echo ""
    echo "All 3 environments have been deleted:"
    echo "- Dev cluster"
    echo "- Staging cluster"
    echo "- Production cluster"
    echo ""
    echo "Cost: \$0/hour (all clusters stopped)"
    echo ""
    echo "Verify in AWS Console that everything is deleted."
    echo ""
    exit 0
else
    destroy_single_env $1 "prompt"
    echo "IMPORTANT: Verify in AWS Console:"
    echo "- EC2 Instances are terminated"
    echo "- Load Balancers are deleted"
    echo "- EKS Cluster is gone"
    echo ""
    echo "Check your AWS bill in 24 hours to confirm zero usage."
    echo ""
fi
