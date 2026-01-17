@echo off
REM DevOps CI/CD Project - Infrastructure Cleanup Script
REM Usage: destroy.cmd [environment]
REM Example: destroy.cmd dev
REM Or: destroy.cmd (destroys all 3 environments)

setlocal

if "%1"=="" (
    echo ========================================
    echo  DevOps CI/CD - Destroy ALL Environments
    echo ========================================
    echo.
    echo No environment specified. Will destroy ALL 3 environments:
    echo - Dev
    echo - Staging
    echo - Production
    echo.
    echo WARNING: This will delete everything!
    echo This will take approximately 20-25 minutes
    echo.
    echo Press Ctrl+C to cancel, or
    pause

    call :destroy_env dev
    if errorlevel 1 exit /b 1

    call :destroy_env staging
    if errorlevel 1 exit /b 1

    call :destroy_env prod
    if errorlevel 1 exit /b 1

    echo.
    echo ========================================
    echo  ALL ENVIRONMENTS DESTROYED!
    echo ========================================
    echo.
    echo All 3 environments have been deleted:
    echo - Dev cluster
    echo - Staging cluster
    echo - Production cluster
    echo.
    echo Cost: $0/hour (all clusters stopped)
    echo.
    echo Verify in AWS Console that everything is deleted.
    echo.
    pause
    exit /b 0
)

set ENV=%1

:destroy_env
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
if not "%1"=="" (
    echo Press Ctrl+C to cancel or
    pause
)

echo.
echo [1/4] Deleting Kubernetes resources...
echo ========================================
kubectl delete namespace %ENV% --force --grace-period=0 2>nul
if errorlevel 1 (
    echo Warning: Kubernetes namespace deletion failed or already deleted
) else (
    echo Kubernetes namespace %ENV% deleted successfully
)

echo.
echo [2/4] Deleting LoadBalancers...
echo ========================================
echo Finding and deleting LoadBalancers for %ENV% environment...

REM Get cluster name for this environment
cd terraform
for /f "delims=" %%i in ('terraform output -raw cluster_name 2^>nul') do set CLUSTER_NAME=%%i
cd ..

REM Delete all LoadBalancers (both classic ELB and ALB/NLB)
for /f "tokens=*" %%i in ('aws elb describe-load-balancers --region eu-central-1 --query "LoadBalancerDescriptions[*].LoadBalancerName" --output text 2^>nul') do (
    echo Deleting LoadBalancer: %%i
    aws elb delete-load-balancer --load-balancer-name %%i --region eu-central-1 2>nul
)

for /f "tokens=*" %%i in ('aws elbv2 describe-load-balancers --region eu-central-1 --query "LoadBalancers[*].LoadBalancerArn" --output text 2^>nul') do (
    echo Deleting ALB/NLB: %%i
    aws elbv2 delete-load-balancer --load-balancer-arn %%i --region eu-central-1 2>nul
)

echo Waiting for LoadBalancers to be fully deleted...
timeout /t 30 /nobreak >nul

echo.
echo [3/4] Switching Terraform workspace...
echo ========================================
cd terraform
terraform init

REM Switch to appropriate workspace
if "%ENV%"=="dev" (
    echo Selecting default workspace for dev...
    terraform workspace select default 2>nul
) else (
    echo Selecting %ENV% workspace...
    terraform workspace select %ENV% 2>nul
)

echo.
echo [4/4] Destroying Terraform infrastructure...
echo ========================================
terraform destroy -var-file="%ENV%.tfvars" -auto-approve

if errorlevel 1 (
    echo.
    echo ERROR: Terraform destroy failed!
    echo Please check the error messages above.
    echo You may need to manually delete resources from AWS Console.
    cd ..
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
if "%1"=="" exit /b 0
echo IMPORTANT: Verify in AWS Console:
echo - EC2 Instances are terminated
echo - Load Balancers are deleted
echo - EKS Cluster is gone
echo.
echo Check your AWS bill in 24 hours to confirm zero usage.
echo.
pause
exit /b 0
