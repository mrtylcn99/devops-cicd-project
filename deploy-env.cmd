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
echo [1/6] Creating infrastructure...
cd terraform >nul 2>&1
if "%ENV%"=="dev" (
    terraform workspace select default >nul 2>&1 || terraform workspace new default >nul 2>&1
) else (
    terraform workspace select %ENV% >nul 2>&1 || terraform workspace new %ENV% >nul 2>&1
)
terraform apply -var-file="%ENV%.tfvars" -auto-approve
cd .. >nul 2>&1
echo [1/6] Done

echo.
echo [2/6] Configuring kubectl...
for /f "delims=" %%i in ('aws eks list-clusters --region eu-central-1 --query "clusters[?contains(@, ''%ENV%'')]" --output text') do (
    aws eks update-kubeconfig --region eu-central-1 --name %%i >nul 2>&1
)
echo [2/6] Done

echo.
echo [3/6] Creating namespaces...
kubectl apply -f k8s/namespace.yaml >nul 2>&1
echo [3/6] Done

echo.
echo [4/6] Installing Argo CD...
kubectl create namespace argocd >nul 2>&1
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml >nul 2>&1
timeout /t 45 /nobreak >nul
echo Setting admin password...
kubectl -n argocd patch secret argocd-secret -p "{\"stringData\": {\"admin.password\": \"$2a$10$rRyBsGSHK6.uc8fntPwVIuLgs7mO9d.T.SrXdl9/..0vQPzQ7TL3S\", \"admin.passwordMtime\": \"2026-01-22T00:00:00Z\"}}" >nul 2>&1
kubectl -n argocd rollout restart deployment argocd-server >nul 2>&1
timeout /t 15 /nobreak >nul
echo [4/6] Done (Password: DevOps2024!)

echo.
echo [5/6] Deploying Argo CD Application...
kubectl apply -f argocd/%ENV%-application.yaml >nul 2>&1
timeout /t 15 /nobreak >nul
kubectl get nodes
echo [5/6] Done

echo.
echo [6/6] Triggering CI/CD...
git commit --allow-empty -m "deploy: Trigger CI/CD for %ENV%" >nul 2>&1
if errorlevel 1 (
    echo ERROR: Git commit failed
    exit /b 1
)
git push origin %ENV%
if errorlevel 1 (
    echo ERROR: Git push failed
    exit /b 1
)
echo [6/6] Done

echo.
echo %ENV% deployed.
