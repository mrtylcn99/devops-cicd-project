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
echo [1/7] Creating infrastructure...
cd terraform
if "%ENV%"=="dev" (
    terraform workspace select default || terraform workspace new default
) else (
    terraform workspace select %ENV% || terraform workspace new %ENV%
)
terraform apply -var-file="%ENV%.tfvars" -auto-approve
if errorlevel 1 (
    echo ERROR: Terraform apply failed
    cd ..
    exit /b 1
)
cd ..
echo [1/7] Done

echo.
echo [2/7] Configuring kubectl...
set CLUSTER_NAME=devops-cicd-%ENV%-cluster
echo Updating kubeconfig for cluster: %CLUSTER_NAME%
aws eks update-kubeconfig --region eu-central-1 --name %CLUSTER_NAME%
if errorlevel 1 (
    echo ERROR: kubectl config update failed
    exit /b 1
)
echo Testing kubectl connection...
kubectl get nodes
if errorlevel 1 (
    echo ERROR: Cannot connect to cluster
    exit /b 1
)
echo [2/7] Done

echo.
echo [3/7] Creating namespaces...
kubectl apply -f k8s/namespace.yaml
if errorlevel 1 (
    echo ERROR: Namespace creation failed
    exit /b 1
)
echo [3/7] Done

echo.
echo [4/7] Installing Argo CD...
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
if errorlevel 1 (
    echo ERROR: Argo CD installation failed
    exit /b 1
)
echo Waiting for Argo CD pods to be ready (60 seconds)...
timeout /t 60 /nobreak >nul
echo Scaling down unnecessary Argo CD components...
kubectl scale deployment argocd-dex-server -n argocd --replicas=0
kubectl scale deployment argocd-notifications-controller -n argocd --replicas=0
kubectl scale deployment argocd-applicationset-controller -n argocd --replicas=0
echo Setting admin password (DevOps2024!)...
kubectl -n argocd patch secret argocd-secret -p "{\"stringData\": {\"admin.password\": \"$2a$10$rRyBsGSHK6.uc8fntPwVIuLgs7mO9d.T.SrXdl9/..0vQPzQ7TL3S\", \"admin.passwordMtime\": \"2026-01-22T00:00:00Z\"}}"
kubectl -n argocd rollout restart deployment argocd-server
timeout /t 15 /nobreak >nul
echo [4/7] Done (Password: DevOps2024!)

echo.
echo [5/7] Deploying Argo CD Application...
kubectl apply -f argocd/%ENV%-application.yaml
if errorlevel 1 (
    echo ERROR: Argo CD application deployment failed
    exit /b 1
)
timeout /t 10 /nobreak >nul
kubectl get application -n argocd
echo [5/7] Done

echo.
echo [6/7] Creating trigger file for CI/CD...
echo %date% %time% > .deploy-trigger
git add .deploy-trigger
git commit -m "deploy: Trigger CI/CD for %ENV% at %date% %time%"
if errorlevel 1 (
    echo WARNING: Git commit failed (maybe no changes)
    echo Creating empty commit as fallback...
    git commit --allow-empty -m "deploy: Trigger CI/CD for %ENV%"
)
git push origin %ENV%
if errorlevel 1 (
    echo WARNING: Push failed, pulling remote changes...
    git pull --rebase origin %ENV%
    if errorlevel 1 (
        echo ERROR: Git pull/rebase failed - resolve conflicts manually
        exit /b 1
    )
    echo Retrying push after rebase...
    git push origin %ENV%
    if errorlevel 1 (
        echo ERROR: Git push failed after rebase
        exit /b 1
    )
)
echo [6/7] Done

echo.
echo [7/7] Waiting for CI/CD pipeline...
echo GitHub Actions should start building in ~30 seconds
echo Check: https://github.com/mrtylcn99/devops-cicd-project/actions
timeout /t 30 /nobreak >nul
echo [7/7] Done

echo.
echo ========================================
echo %ENV% deployment initiated successfully!
echo ========================================
echo.
echo Next steps:
echo 1. Monitor GitHub Actions: https://github.com/mrtylcn99/devops-cicd-project/actions
echo 2. Check Argo CD sync: kubectl get application -n argocd
echo 3. Get LoadBalancer URL: kubectl get svc -n %ENV%
echo.
