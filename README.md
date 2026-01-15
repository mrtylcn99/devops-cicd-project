# DevOps CI/CD Pipeline with AWS EKS

Production-ready CI/CD pipeline demonstrating modern DevOps practices with Kubernetes, Terraform, and GitHub Actions.

## Overview

Automated deployment pipeline for a Flask application across three isolated environments (Dev, Staging, Production) using AWS EKS, managed entirely through Infrastructure as Code.

**Live Demo:** [Dev Environment](http://aff32291cf39944c2949c9aafb07efe7-262667895.eu-central-1.elb.amazonaws.com)

## Tech Stack

- **Application:** Python Flask with Gunicorn
- **Containerization:** Docker + Amazon ECR
- **Orchestration:** Kubernetes (AWS EKS)
- **Infrastructure:** Terraform
- **CI/CD:** GitHub Actions
- **Cloud Provider:** AWS (EKS, EC2, ECR, IAM)

## Features

- **Multi-Environment Support:** Dev, Staging, Production
- **Automated CI/CD:** Push-to-deploy workflow
- **Infrastructure as Code:** Complete Terraform configuration
- **Secure Secrets:** GitHub Secrets integration
- **Health Monitoring:** Automated readiness and liveness probes
- **Cost Optimized:** Single-command infrastructure cleanup

## Quick Start

### Prerequisites

- AWS Account with configured credentials
- GitHub account
- Docker Desktop
- Terraform >= 1.0
- kubectl

### 1. Clone and Setup

```bash
git clone https://github.com/mrtylcn99/devops-cicd-project.git
cd devops-cicd-project
```

### 2. Configure GitHub Secrets

Navigate to: `Settings → Secrets → Actions → New repository secret`

Add:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 3. Deploy Infrastructure (Choose One Method)

**Option A - Automated Script (Recommended):**

Windows:
```cmd
deploy-env.cmd dev
```

Linux/Mac:
```bash
./deploy-env.sh dev
```

This script automatically:
- Deploys Terraform infrastructure
- Configures kubectl with your cluster
- Creates Kubernetes namespaces
- Verifies nodes are ready

**Time:** ~15 minutes
**Cost:** ~$0.13/hour

**Option B - Manual Deployment:**

```bash
cd terraform
terraform init
terraform apply -var-file="dev.tfvars"
aws eks update-kubeconfig --region eu-central-1 --name <cluster-name>
kubectl apply -f k8s/namespace.yaml
```

### 4. Deploy Application

```bash
git checkout dev
git push origin dev
```

GitHub Actions automatically builds, pushes, and deploys your application.

## Environment Configuration

| Environment | Branch    | Replicas | Instance  | Deploy |
|-------------|-----------|----------|-----------|--------|
| Dev         | `dev`     | 1        | t3.small  | Auto   |
| Staging     | `staging` | 1        | t3.small  | Auto   |
| Production  | `main`    | 2        | t3.medium | Auto   |

## CI/CD Pipeline

```
Code Push → GitHub Actions → Docker Build → ECR Push → EKS Deploy → Health Check
```

**Duration:** 5-7 minutes per deployment

## Automation Scripts

This project includes automation scripts for easy deployment and cleanup.

### deploy-env.cmd / deploy-env.sh

**Purpose:** Complete environment setup from scratch

**What it does:**
1. Runs `terraform init` and `terraform apply` with the specified environment
2. Automatically configures kubectl to connect to your new EKS cluster
3. Creates Kubernetes namespaces (dev/staging/prod)
4. Waits for nodes to be ready
5. Displays next steps

**Usage:**
```bash
# Windows
deploy-env.cmd [environment]

# Linux/Mac
./deploy-env.sh [environment]

# Examples
deploy-env.cmd dev
deploy-env.cmd staging
```

**When to use:** First-time setup or after running destroy

### destroy.cmd / destroy.sh

**Purpose:** Complete infrastructure cleanup

**What it does:**
1. Deletes Kubernetes namespace and all resources (pods, services, etc.)
2. Waits 3 minutes for AWS LoadBalancer to be deleted
3. Runs `terraform destroy` to remove all AWS infrastructure
4. Verifies completion

**Usage:**
```bash
# Windows
destroy.cmd [environment]

# Linux/Mac
./destroy.sh [environment]

# Examples
destroy.cmd dev
./destroy.sh staging
```

**When to use:** After testing to avoid AWS costs

**Important:** Always destroy environments when not in use to avoid charges!

## Cost Management

**EKS Cluster:** $0.10/hour (~$72/month if left running)

### Quick Cleanup

Use the automation scripts above, or manual cleanup:

**Manual:**
```bash
kubectl delete namespace dev --force
cd terraform
terraform destroy -var-file="dev.tfvars" -auto-approve
```

### Estimated Costs

| Usage          | Duration | Cost    |
|----------------|----------|---------|
| 2-hour test    | 2h       | ~$0.25  |
| Daily testing  | 8h       | ~$1.00  |
| Forgot to stop | 30d      | ~$150   |

## Local Development

```bash
# Build image
docker build -t devops-app:latest .

# Run container
docker run -p 5000:5000 -e ENVIRONMENT=dev devops-app:latest

# Test endpoint
curl http://localhost:5000
```

**Expected Response:**
```json
{
  "message": "Merhaba! DevOps projene hoş geldin! 🚀",
  "environment": "dev",
  "hostname": "container-id",
  "status": "healthy",
  "version": "1.0.0"
}
```

## Deployment Commands

### Deploy Staging

```bash
cd terraform
terraform apply -var-file="staging.tfvars" -auto-approve
git push origin staging
```

### Deploy Production

```bash
cd terraform
terraform apply -var-file="prod.tfvars" -auto-approve
git push origin main
```

## Monitoring

```bash
# Check pods
kubectl get pods -n dev

# View logs
kubectl logs -f deployment/devops-app -n dev

# Get service URL
kubectl get svc devops-app-service -n dev
```

## Security

- Secrets managed via GitHub Secrets (never committed)
- IAM roles with least privilege
- Container image scanning enabled
- Resource limits enforced
- Network policies configured

## Troubleshooting

**Pod not starting:**
```bash
kubectl describe pod <pod-name> -n dev
kubectl logs <pod-name> -n dev
```

**LoadBalancer pending:**
Wait 2-3 minutes for AWS to provision. Check with:
```bash
kubectl get svc -n dev --watch
```

**Terraform errors:**
```bash
terraform state list
terraform state rm <problematic-resource>
terraform apply -var-file="dev.tfvars"
```

## Project Structure

```
.
├── app.py                   # Flask application
├── Dockerfile               # Container definition
├── requirements.txt         # Python dependencies
├── terraform/               # Infrastructure code
│   ├── main.tf             # AWS resources
│   ├── variables.tf        # Variable definitions
│   ├── outputs.tf          # Output values
│   └── *.tfvars           # Environment configs
├── k8s/                    # Kubernetes manifests
│   ├── namespace.yaml     # Namespace definitions
│   └── deployment.yaml    # Deployment & Service
└── .github/workflows/      # CI/CD pipelines
    └── cicd.yaml

```

## What You'll Learn

- Docker containerization and multi-stage builds
- Kubernetes orchestration and resource management
- Terraform infrastructure automation
- GitHub Actions CI/CD pipelines
- AWS EKS cluster management
- Multi-environment deployment strategies
- Secret management best practices
- Cost optimization techniques

## Argo CD (GitOps)

**Status:** ✅ Implemented

Argo CD is installed on the dev cluster for GitOps-style deployments.

**Access:**
- URL: http://a695fd93356ba4669b7707b4aa7e7d5b-421387763.eu-central-1.elb.amazonaws.com
- Username: `admin`
- Password: Run `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d`

**Features:**
- Automated sync from Git repository
- Self-healing deployments
- Declarative GitOps workflow

## Future Enhancements

- [ ] Prometheus & Grafana monitoring
- [ ] Helm chart deployment
- [ ] Blue-Green deployments
- [ ] Automated testing suite
- [ ] SSL/TLS configuration

## Submission Checklist

If you're submitting this project, ensure you have:

- [ ] GitHub repository with all code pushed
- [ ] GitHub Actions CI/CD pipeline working
- [ ] At least one environment deployed and tested
- [ ] README.md with clear instructions
- [ ] AWS credentials configured as GitHub Secrets (never in code)
- [ ] All 3 environment configs (dev.tfvars, staging.tfvars, prod.tfvars)
- [ ] Automation scripts (deploy-env, destroy) working
- [ ] Argo CD installed (optional but recommended)
- [ ] Infrastructure destroyed after testing to avoid costs

**What to share:**
- Repository URL: https://github.com/mrtylcn99/devops-cicd-project
- Live demo URL (if still running)
- Screenshots of deployed application
- Screenshots of Argo CD UI (if implemented)

## Contributing

Pull requests are welcome. For major changes, please open an issue first.

## License

This project is for educational purposes and is freely available.

## Author

**Mert Yalçın** - [@mrtylcn99](https://github.com/mrtylcn99)

---

⚠️ **Remember:** Always run `terraform destroy` after testing to avoid unnecessary costs!
