@echo off
setlocal enabledelayedexpansion

set ENV=%1
if "%ENV%"=="" (
    echo Usage: destroy.cmd [dev^|staging^|prod]
    exit /b 1
)

set /p CONFIRM="Delete %ENV%? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Cancelled.
    exit /b 0
)

echo.
echo [1/4] Deleting Argo CD Application...
kubectl delete application devops-app-%ENV% -n argocd >nul 2>&1
echo [1/4] Done

echo.
echo [2/4] Deleting namespace...
kubectl delete namespace %ENV% --force --grace-period=0 >nul 2>&1
kubectl delete namespace argocd --force --grace-period=0 >nul 2>&1
echo [2/4] Done

echo.
echo [3/4] Deleting LoadBalancers...
for /f "tokens=*" %%i in ('aws elb describe-load-balancers --region eu-central-1 --query "LoadBalancerDescriptions[*].LoadBalancerName" --output text 2^>nul') do (
    aws elb delete-load-balancer --load-balancer-name %%i --region eu-central-1 2>nul
)
for /f "tokens=*" %%i in ('aws elbv2 describe-load-balancers --region eu-central-1 --query "LoadBalancers[*].LoadBalancerArn" --output text 2^>nul') do (
    aws elbv2 delete-load-balancer --load-balancer-arn %%i --region eu-central-1 2>nul
)
timeout /t 30 /nobreak >nul
echo [3/4] Done

echo.
echo [4/4] Destroying infrastructure...
cd terraform >nul 2>&1
if "%ENV%"=="dev" (terraform workspace select default >nul 2>&1) else (terraform workspace select %ENV% >nul 2>&1)
terraform destroy -var-file="%ENV%.tfvars" -auto-approve
cd .. >nul 2>&1
echo [4/4] Done

echo.
echo %ENV% destroyed.
