@echo off
REM DevOps CI/CD Project - Infrastructure Cleanup Script
REM Usage: destroy.cmd [environment]
REM Example: destroy.cmd dev

setlocal

if "%1"=="" (
    echo ERROR: Environment parameter required!
    echo.
    echo Usage: destroy.cmd [environment]
    echo Example: destroy.cmd dev
    echo.
    echo Available environments: dev, staging, prod
    exit /b 1
)

set ENV=%1

echo ========================================
echo  DevOps CI/CD - Cleanup Script
echo ========================================
echo.
echo Environment: %ENV%
echo.
echo WARNING: This will delete ALL resources in %ENV% environment!
echo - EKS Cluster
echo - EC2 Instances
echo - Load Balancer
echo - ECR Repository
echo.
echo Press Ctrl+C to cancel or
pause

echo.
echo [1/3] Deleting Kubernetes resources...
echo ========================================
kubectl delete namespace %ENV% --force --grace-period=0 2>nul
if errorlevel 1 (
    echo Warning: Kubernetes namespace deletion failed or already deleted
) else (
    echo Kubernetes namespace %ENV% deleted successfully
)

echo.
echo [2/3] Waiting for LoadBalancer to be deleted...
echo ========================================
echo This may take 2-3 minutes...
timeout /t 180 /nobreak >nul

echo.
echo [3/3] Destroying Terraform infrastructure...
echo ========================================
cd terraform
terraform destroy -var-file="%ENV%.tfvars" -auto-approve

if errorlevel 1 (
    echo.
    echo ERROR: Terraform destroy failed!
    echo Please check the error messages above.
    echo You may need to manually delete resources from AWS Console.
    exit /b 1
)

cd ..

echo.
echo ========================================
echo  CLEANUP COMPLETED SUCCESSFULLY!
echo ========================================
echo.
echo Environment %ENV% has been destroyed.
echo.
echo IMPORTANT: Verify in AWS Console:
echo - EC2 Instances are terminated
echo - Load Balancers are deleted
echo - EKS Cluster is gone
echo.
echo Check your AWS bill in 24 hours to confirm zero usage.
echo.
pause
