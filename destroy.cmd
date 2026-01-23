@echo off
setlocal enabledelayedexpansion

set ENV=%1
if "%ENV%"=="" (
    echo Usage: destroy.cmd [dev^|staging^|prod]
    exit /b 1
)

echo.
echo ========================================
echo WARNING: This will DELETE all resources in %ENV%!
echo ========================================
echo.
set /p CONFIRM="Are you SURE you want to delete %ENV%? Type 'DELETE' to confirm: "
if /i not "%CONFIRM%"=="DELETE" (
    echo Cancelled.
    exit /b 0
)

echo.
echo [1/6] Checking cluster connection...
aws eks update-kubeconfig --region eu-central-1 --name devops-cicd-%ENV%-cluster 2>nul
if errorlevel 1 (
    echo WARNING: Cannot connect to cluster - it may already be deleted
    goto :skip_k8s_cleanup
)
kubectl get nodes
if errorlevel 1 (
    echo WARNING: Cannot access cluster - skipping Kubernetes cleanup
    goto :skip_k8s_cleanup
)
echo [1/6] Done

echo.
echo [2/6] Deleting Argo CD Application...
kubectl delete application devops-app-%ENV% -n argocd --ignore-not-found=true
echo [2/6] Done

echo.
echo [3/6] Deleting namespaces and waiting for resources to cleanup...
kubectl delete namespace %ENV% --ignore-not-found=true
kubectl delete namespace argocd --ignore-not-found=true
echo Waiting 60 seconds for LoadBalancers to be removed by controllers...
timeout /t 60 /nobreak >nul
echo [3/6] Done

:skip_k8s_cleanup

echo.
echo [4/6] Checking for orphaned node groups...
for /f "delims=" %%i in ('aws eks list-nodegroups --cluster-name devops-cicd-%ENV%-cluster --region eu-central-1 --query "nodegroups" --output text 2^>nul') do (
    echo Deleting node group: %%i
    aws eks delete-nodegroup --cluster-name devops-cicd-%ENV%-cluster --nodegroup-name %%i --region eu-central-1
    echo Waiting for node group deletion...
    :wait_nodegroup
    aws eks describe-nodegroup --cluster-name devops-cicd-%ENV%-cluster --nodegroup-name %%i --region eu-central-1 >nul 2>&1
    if not errorlevel 1 (
        timeout /t 15 /nobreak >nul
        goto :wait_nodegroup
    )
)
echo [4/6] Done

echo.
echo [5/6] Checking for orphaned LoadBalancers...
for /f "tokens=*" %%i in ('aws elbv2 describe-load-balancers --region eu-central-1 --query "LoadBalancers[?contains(LoadBalancerName, ''k8s'') ^|| contains(LoadBalancerName, ''devops'')].LoadBalancerArn" --output text 2^>nul') do (
    echo Deleting LoadBalancer: %%i
    aws elbv2 delete-load-balancer --load-balancer-arn %%i --region eu-central-1
)
timeout /t 30 /nobreak >nul
echo [5/6] Done

echo.
echo [6/6] Destroying infrastructure with Terraform...
cd terraform
if "%ENV%"=="dev" (
    terraform workspace select default
) else (
    terraform workspace select %ENV%
)
if errorlevel 1 (
    echo ERROR: Cannot select terraform workspace
    cd ..
    exit /b 1
)
terraform destroy -var-file="%ENV%.tfvars" -auto-approve
if errorlevel 1 (
    echo ERROR: Terraform destroy failed
    echo Please check for orphaned resources manually
    cd ..
    exit /b 1
)
cd ..
echo [6/6] Done

echo.
echo ========================================
echo %ENV% destroyed successfully!
echo ========================================
echo.
echo Verifying cleanup...
echo.
echo Clusters:
aws eks list-clusters --region eu-central-1 --query "clusters" --output table
echo.
echo ECR Repositories:
aws ecr describe-repositories --region eu-central-1 --query "repositories[?contains(repositoryName, 'devops-cicd')].repositoryName" --output table 2>nul
echo.
echo LoadBalancers:
aws elbv2 describe-load-balancers --region eu-central-1 --query "LoadBalancers[?contains(LoadBalancerName, 'k8s')].LoadBalancerName" --output table 2>nul
echo.
echo If you see any resources above, they may need manual cleanup!
echo.
echo ========================================
echo Manual Cleanup Commands (if needed):
echo ========================================
echo.
echo To delete a specific EKS cluster:
echo   aws eks delete-cluster --name CLUSTER_NAME --region eu-central-1
echo.
echo To delete a specific ECR repository:
echo   aws ecr delete-repository --repository-name REPO_NAME --region eu-central-1 --force
echo.
echo To delete all LoadBalancers with 'k8s' in name:
echo   for /f "delims=" %%%%i in ('aws elbv2 describe-load-balancers --region eu-central-1 --query "LoadBalancers[?contains(LoadBalancerName, 'k8s')].LoadBalancerArn" --output text') do aws elbv2 delete-load-balancer --load-balancer-arn %%%%i --region eu-central-1
echo.
echo ========================================
echo.
