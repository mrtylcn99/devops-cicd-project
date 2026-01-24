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
echo [0/7] Switching to %ENV% branch...
git fetch origin %ENV%
git checkout %ENV%
if errorlevel 1 (
    echo ERROR: Could not switch to %ENV% branch
    exit /b 1
)
git pull origin %ENV%
echo [0/7] Done

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
echo [1.5/7] Verifying ECR repository...
set ECR_REPO_NAME=devops-cicd-%ENV%
echo Waiting for ECR repository: %ECR_REPO_NAME%
set ECR_READY=0
for /L %%i in (1,1,30) do (
    aws ecr describe-repositories --repository-names %ECR_REPO_NAME% --region eu-central-1 >nul 2>&1
    if not errorlevel 1 (
        echo ECR repository found!
        set ECR_READY=1
        goto ecr_ready
    )
    echo Waiting for ECR... (%%i/30^)
    timeout /t 2 /nobreak >nul
)
:ecr_ready
if %ECR_READY%==0 (
    echo ERROR: ECR repository not created after 60 seconds
    exit /b 1
)
echo [1.5/7] Done

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
echo Waiting for initial admin secret to be generated...
timeout /t 15 /nobreak >nul
echo Getting initial admin password...
for /f "delims=" %%i in ('kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath^="{.data.password}" 2^>nul') do set B64_PASSWORD=%%i
for /f "delims=" %%i in ('powershell -Command "[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('%B64_PASSWORD%'))"') do set ADMIN_PASSWORD=%%i
if "%ADMIN_PASSWORD%"=="" (
    echo WARNING: Could not retrieve initial admin password
    echo You can get it later with: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" ^| base64 -d
    echo [4/7] Done
) else (
    echo [4/7] Done
    echo.
    echo ========================================
    echo Argo CD Admin Password: %ADMIN_PASSWORD%
    echo ========================================
)

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
echo Cleaning up any temporary files...
del temp_pass.txt decoded_pass.txt nul workflow_status.txt workflow_conclusion.txt sync_status.txt health_status.txt 2>nul
echo Creating deploy trigger...
echo %date% %time% > .deploy-trigger
git add .deploy-trigger
git commit -m "deploy: Trigger CI/CD for %ENV% at %date% %time%"
if errorlevel 1 (
    echo WARNING: Git commit failed, trying empty commit...
    git commit --allow-empty -m "deploy: Trigger CI/CD for %ENV%"
    if errorlevel 1 (
        echo WARNING: Empty commit also failed, continuing...
    )
)
echo Fetching latest changes from remote...
git fetch origin %ENV%
echo Merging remote changes (our version takes precedence)...
git merge origin/%ENV% --no-edit --strategy-option=ours -m "deploy: Merge remote changes for %ENV%" 2>nul
if errorlevel 1 (
    echo WARNING: Merge had conflicts, resolving with our version...
    git merge -X ours origin/%ENV% --no-edit 2>nul
    if errorlevel 1 (
        echo ERROR: Could not resolve merge conflicts
        git merge --abort 2>nul
        exit /b 1
    )
)
echo Pushing to remote...
git push origin %ENV%
if errorlevel 1 (
    echo ERROR: Git push failed
    echo Attempting force push...
    git push origin %ENV% --force-with-lease
    if errorlevel 1 (
        echo ERROR: Force push also failed. Check GitHub manually.
        exit /b 1
    )
)
echo [6/7] Done

echo.
echo [7/7] Waiting for CI/CD pipeline...
echo GitHub Actions should start building Docker image...
echo Check: https://github.com/mrtylcn99/devops-cicd-project/actions
echo.
echo Waiting for workflow to complete (checking every 10 seconds)...
set WAIT_COUNT=0
:wait_loop
timeout /t 10 /nobreak >nul
set /a WAIT_COUNT+=1
gh run list --repo mrtylcn99/devops-cicd-project --branch %ENV% --limit 1 --json status,conclusion -q ".[0].status" > workflow_status.txt 2>nul
set /p WORKFLOW_STATUS=<workflow_status.txt
if "%WORKFLOW_STATUS%"=="completed" (
    gh run list --repo mrtylcn99/devops-cicd-project --branch %ENV% --limit 1 --json status,conclusion -q ".[0].conclusion" > workflow_conclusion.txt 2>nul
    set /p WORKFLOW_CONCLUSION=<workflow_conclusion.txt
    del workflow_status.txt workflow_conclusion.txt 2>nul
    if "%WORKFLOW_CONCLUSION%"=="success" (
        echo Workflow completed successfully! Docker image built and pushed to ECR.
        goto workflow_done
    ) else (
        echo WARNING: Workflow completed but failed. Check GitHub Actions for errors.
        goto workflow_done
    )
)
if %WAIT_COUNT% LSS 12 (
    echo Still waiting... (%WAIT_COUNT%/12 - max 2 minutes^)
    goto wait_loop
)
del workflow_status.txt 2>nul
echo WARNING: Workflow still running after 2 minutes.
echo Check workflow status manually: https://github.com/mrtylcn99/devops-cicd-project/actions
echo Continuing to Argo CD sync check...
:workflow_done

echo.
echo [7.5/7] Verifying Argo CD sync...
echo Waiting for Argo CD to sync application (max 2 minutes)...
set SYNC_WAIT=0
:sync_wait_loop
timeout /t 10 /nobreak >nul
set /a SYNC_WAIT+=1
kubectl get application devops-app-%ENV% -n argocd -o jsonpath="{.status.sync.status}" > sync_status.txt 2>nul
set /p SYNC_STATUS=<sync_status.txt
kubectl get application devops-app-%ENV% -n argocd -o jsonpath="{.status.health.status}" > health_status.txt 2>nul
set /p HEALTH_STATUS=<health_status.txt
del sync_status.txt health_status.txt 2>nul
echo Status: Sync=%SYNC_STATUS%, Health=%HEALTH_STATUS%
if "%SYNC_STATUS%"=="Synced" (
    if "%HEALTH_STATUS%"=="Healthy" (
        echo Application is Synced and Healthy!
        goto sync_done
    )
    if "%HEALTH_STATUS%"=="Progressing" (
        if %SYNC_WAIT% LSS 12 (
            echo Still progressing... (%SYNC_WAIT%/12^)
            goto sync_wait_loop
        )
    )
)
if %SYNC_WAIT% LSS 12 (
    echo Waiting for sync... (%SYNC_WAIT%/12^)
    goto sync_wait_loop
)
echo WARNING: Application not fully healthy after 2 minutes
echo Current status - Sync: %SYNC_STATUS%, Health: %HEALTH_STATUS%
echo Check manually: kubectl get application devops-app-%ENV% -n argocd
:sync_done
echo [7.5/7] Done

echo.
echo ========================================
echo %ENV% deployment completed successfully!
echo ========================================
echo.
echo Resources:
echo 1. GitHub Actions: https://github.com/mrtylcn99/devops-cicd-project/actions
echo 2. Argo CD Status: kubectl get application -n argocd
echo 3. Application Pods: kubectl get pods -n %ENV%
echo 4. LoadBalancer URL: kubectl get svc -n %ENV%
echo.
echo ========================================
echo Argo CD UI Access
echo ========================================
if not "%ADMIN_PASSWORD%"=="" (
    echo Username: admin
    echo Password: %ADMIN_PASSWORD%
    echo.
    echo To access Argo CD UI, run this command in a NEW terminal:
    echo kubectl port-forward svc/argocd-server -n argocd 9090:443
    echo.
    echo Then open: https://localhost:9090
    echo.
) else (
    echo To get Argo CD password:
    echo kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" ^| base64 -d
    echo.
)
echo ========================================
echo.
