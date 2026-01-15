@echo off
REM DevOps CI/CD Project - Quick Environment Setup
REM Usage: deploy-env.cmd [environment]
REM Example: deploy-env.cmd staging
REM Or: deploy-env.cmd (deploys all 3 environments)

setlocal

if "%1"=="" (
    echo ========================================
    echo  DevOps CI/CD - Deploy ALL Environments
    echo ========================================
    echo.
    echo No environment specified. Will deploy ALL 3 environments:
    echo - Dev
    echo - Staging
    echo - Production
    echo.
    echo This will take approximately 45-60 minutes
    echo Cost: ~$0.30/hour after completion
    echo.
    echo Press Ctrl+C to cancel, or
    pause

    call :deploy_env dev
    if errorlevel 1 exit /b 1

    call :deploy_env staging
    if errorlevel 1 exit /b 1

    call :deploy_env prod
    if errorlevel 1 exit /b 1

    echo.
    echo ========================================
    echo  ALL ENVIRONMENTS DEPLOYED!
    echo ========================================
    echo.
    echo All 3 environments are ready:
    echo - Dev cluster
    echo - Staging cluster
    echo - Production cluster
    echo.
    echo WARNING: 3 clusters running = $0.30/hour = ~$216/month
    echo Don't forget to destroy when done!
    echo.
    pause
    exit /b 0
)

set ENV=%1

:deploy_env
set ENV=%1

echo ========================================
echo  DevOps CI/CD - Environment Setup
echo ========================================
echo.
echo Environment: %ENV%
echo.
echo This script will:
echo 1. Deploy Terraform infrastructure
echo 2. Configure kubectl
echo 3. Create Kubernetes namespaces
echo.
echo Estimated time: 15-20 minutes
echo Estimated cost: ~$0.13/hour
echo.
pause

echo.
echo [1/4] Deploying Terraform infrastructure...
echo ========================================
cd terraform
terraform init
terraform apply -var-file="%ENV%.tfvars" -auto-approve

if errorlevel 1 (
    echo.
    echo ERROR: Terraform deployment failed!
    exit /b 1
)

echo.
echo [2/4] Configuring kubectl...
echo ========================================
for /f "delims=" %%i in ('terraform output -raw cluster_name') do set CLUSTER_NAME=%%i
aws eks update-kubeconfig --region eu-central-1 --name %CLUSTER_NAME%

echo.
echo [3/4] Creating Kubernetes namespaces...
echo ========================================
cd ..
kubectl apply -f k8s/namespace.yaml

echo.
echo [4/4] Waiting for nodes to be ready...
echo ========================================
timeout /t 30 /nobreak >nul
kubectl get nodes

echo.
echo ========================================
echo  SETUP COMPLETED SUCCESSFULLY!
echo ========================================
echo.
echo Environment: %ENV%
echo Cluster: %CLUSTER_NAME%
echo.
echo Next steps:
echo 1. Push code to trigger deployment:
echo    git push origin %ENV%
echo.
echo 2. Monitor deployment:
echo    kubectl get pods -n %ENV% --watch
echo.
echo 3. Get application URL:
echo    kubectl get svc devops-app-service -n %ENV%
echo.
echo WARNING: Don't forget to destroy when done!
echo Command: destroy.cmd %ENV%
echo.
if "%1"=="" exit /b 0
pause
exit /b 0
