@echo off
setlocal enabledelayedexpansion

set ENV=%1
if "%ENV%"=="" (
    echo Usage: deploy-env.cmd [dev^|staging^|prod]
    exit /b 1
)

set /p CONFIRM="Deploy %ENV%? (Y/N): "
if /i not "%CONFIRM%"=="Y" (
    echo Cancelled.
    exit /b 0
)

echo.
echo [1/3] Creating infrastructure...
cd terraform >nul 2>&1
if "%ENV%"=="dev" (
    terraform workspace select default >nul 2>&1 || terraform workspace new default >nul 2>&1
) else (
    terraform workspace select %ENV% >nul 2>&1 || terraform workspace new %ENV% >nul 2>&1
)
terraform apply -var-file="%ENV%.tfvars" -auto-approve
cd .. >nul 2>&1
echo [1/3] Done

echo.
echo [2/3] Configuring kubectl...
for /f "delims=" %%i in ('aws eks list-clusters --region eu-central-1 --query "clusters[?contains(@, ''%ENV%'')]" --output text') do (
    aws eks update-kubeconfig --region eu-central-1 --name %%i >nul 2>&1
)
echo [2/3] Done

echo.
echo [3/3] Creating namespaces...
kubectl apply -f k8s/namespace.yaml >nul 2>&1
timeout /t 30 /nobreak >nul
kubectl get nodes
echo [3/3] Done

echo.
echo %ENV% deployed.
echo Push: git push origin %ENV%
