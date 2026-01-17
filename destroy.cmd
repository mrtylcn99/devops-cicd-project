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
echo [1/3] Deleting namespace...
kubectl delete namespace %ENV% --force --grace-period=0 >nul 2>&1
echo [1/3] Done

echo.
echo [2/3] Waiting for LoadBalancer cleanup...
timeout /t 60 /nobreak >nul
echo [2/3] Done

echo.
echo [3/3] Destroying infrastructure...
cd terraform >nul 2>&1
if "%ENV%"=="dev" (terraform workspace select default >nul 2>&1) else (terraform workspace select %ENV% >nul 2>&1)
terraform destroy -var-file="%ENV%.tfvars" -auto-approve
cd .. >nul 2>&1
echo [3/3] Done

echo.
echo %ENV% destroyed.
