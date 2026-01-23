# DevOps CI/CD Project - Technical Notes

## Architecture Overview
- 3 environments: dev, staging, prod
- Each environment: isolated EKS cluster + Argo CD instance + namespace
- CI: GitHub Actions (build Docker, push ECR, update kustomization)
- CD: Argo CD (auto-sync from git, deploy to K8s)
- IaC: Terraform (EKS, ECR, VPC, IAM)
- Git branches: dev, staging, prod (separate per environment)

## Key Components
- EKS 1.31, t3.small nodes (1 per env)
- Argo CD minimal install (4 pods: server, repo-server, redis, application-controller)
- Scaled down: dex-server, notifications-controller, applicationset-controller (0 replicas)
- LoadBalancer service for app exposure
- Kustomize overlays for environment-specific configs

## Critical Fixes Applied

### 1. Argo CD Password Authentication (BLOCKER)
**Problem**: UI login failed with "invalid username or password" for all attempts
**Root Cause**: Argo CD v3.x changed password management - bcrypt patch to argocd-secret no longer works
**Solution**: Retrieve password from argocd-initial-admin-secret using 2-step process:
```cmd
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" > temp
powershell decode base64 from temp file
```
**Files**: deploy-env.cmd:73-79

### 2. Git Push Conflicts During Deploy
**Problem**: Deploy script push failed - "cannot pull with rebase: You have unstaged changes"
**Root Cause**:
- GitHub Actions updates kustomization.yaml (new image tag)
- Deploy script also commits .deploy-trigger
- Race condition + temp files (temp_pass.txt, decoded_pass.txt, nul) left uncommitted
**Solution**:
- Clean temp files before git operations
- Use git stash before rebase
- Escape stderr redirect: 2^>nul instead of 2>nul (prevents "nul" file creation)
**Files**: deploy-env.cmd:104-126

### 3. AWS CLI Query Syntax Error
**Problem**: "Expected 2 arguments for function contains(), received 4"
**Original**: `aws eks list-clusters --query "clusters[?contains(@, ''%ENV%'')]"`
**Solution**: Direct cluster name instead of query
```cmd
set CLUSTER_NAME=devops-cicd-%ENV%-cluster
aws eks update-kubeconfig --name %CLUSTER_NAME%
```
**Files**: deploy-env.cmd:35-37

### 4. GitHub Actions Workflow Branch Mismatch
**Problem**: Prod push didn't trigger workflow - no Docker image built
**Root Cause**: Workflow listened to "main" branch but prod branch is "prod"
**Solution**: Changed workflow trigger from "main" to "prod"
**Files**: .github/workflows/cicd.yaml:6

### 5. Deploy Script Displaying Wrong Info
**Problem**: Script showed password but different from actual (wrong extraction)
**Root Cause**: PowerShell command with kubectl in single line had stderr redirect issues
**Solution**: Split into 2 commands - kubectl extracts base64, PowerShell decodes separately
**Files**: deploy-env.cmd:76-77

## Deployment Flow
1. User runs deploy-env.cmd <env>
2. Terraform creates EKS cluster, ECR, networking
3. Script installs Argo CD, gets password from initial-admin-secret
4. Script creates Argo CD Application pointing to git repo
5. Script commits .deploy-trigger, pushes to git
6. GitHub Actions triggers: build Docker, push ECR, update kustomization.yaml with new tag
7. Argo CD auto-syncs: pulls new manifests, applies to K8s
8. App pods start with latest image from ECR

## Destroy Flow
1. User runs destroy.cmd <env>
2. Detects node groups, waits for deletion
3. Queries LoadBalancers, deletes k8s-* named LBs
4. Terraform destroy (EKS, ECR, VPC)
5. Verifies cleanup, shows remaining resources
6. Provides manual cleanup commands if needed

## Environment Access
**Dev Cluster**:
- Argo CD: kubectl port-forward svc/argocd-server -n argocd 9090:443
- Password: gQMnUQ4JPJ6H5KhK
- App: devops-app-dev (namespace: dev)

**Staging Cluster**:
- Argo CD: kubectl port-forward svc/argocd-server -n argocd 9090:443
- Password: bv4mucLLY4GVhGzI
- App: devops-app-staging (namespace: staging)

**Prod Cluster**:
- Argo CD: kubectl port-forward svc/argocd-server -n argocd 9090:443
- Password: TBD (retrieve after successful deploy)
- App: devops-app-prod (namespace: prod)

## Known Issues & Workarounds
1. Git push "failures" during deploy are normal - GitHub Actions race condition, auto-recovers with rebase
2. Port-forward must reconnect when switching clusters (each env has own Argo CD)
3. "nul" file occasionally created by Windows CMD stderr redirect - cleaned automatically
4. Prod workflow initially didn't trigger - fixed by changing branch from "main" to "prod"

## Multi-Cluster Argo CD Discussion
Current setup: Each environment has isolated Argo CD instance
- Pro: Full isolation, independent failure domains, simpler networking
- Con: Multiple logins, no centralized view

Alternative: Single Argo CD managing all clusters
- Pro: Centralized management, single UI, unified RBAC
- Con: Single point of failure, complex networking, management cluster cost

Decision: Keep isolated Argo CD per environment (simpler for homework, production best practice)

## Terraform Resource Counts
Per environment:
- 1 VPC (2 public subnets)
- 1 EKS cluster
- 1 Node group (t3.small, 1-1-1 scaling)
- 1 ECR repository
- IAM roles: cluster role, node role
- Security groups: cluster SG, node SG

## Testing Checklist
- [x] Dev deploy successful
- [x] Dev Argo CD UI login working
- [x] Dev app synced and healthy
- [x] Staging deploy successful
- [x] Staging Argo CD UI login working
- [x] Staging app synced and healthy
- [ ] Prod deploy pending (workflow fix applied, awaiting redeploy)
- [ ] Prod Argo CD UI login
- [ ] Prod app synced and healthy
- [ ] Final cleanup test (destroy all environments)

## Git Branch Strategy
- dev: active development, frequent changes
- staging: tested features, pre-production validation
- prod: production-ready code, stable releases
- Each branch triggers independent CI/CD pipeline
- Fixes merged: dev -> staging -> prod

## Commands Reference
Deploy: `deploy-env.cmd <env>`
Destroy: `destroy.cmd <env>`
Switch cluster: `aws eks update-kubeconfig --region eu-central-1 --name devops-cicd-<env>-cluster`
Port-forward: `kubectl port-forward svc/argocd-server -n argocd 9090:443`
Get password: `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d`
Watch pods: `kubectl get pods -n <env> -w`
Check app: `kubectl get application -n argocd`

## Session Summary
Total time: ~4 hours
Major blockers: 3 (Argo CD auth, git push conflicts, workflow branch)
Environments deployed: 2/3 (dev ✓, staging ✓, prod in progress)
Scripts updated: deploy-env.cmd, destroy.cmd, cicd.yaml
Commits: 41 across all branches
