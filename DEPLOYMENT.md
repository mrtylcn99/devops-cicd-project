# 🚀 Deployment Rehberi

Bu doküman, projeyi sıfırdan AWS'ye deploy etme adımlarını içerir.

## 📋 Ön Gereksinimler

- AWS hesabı ve credentials yapılandırılmış
- Terraform yüklü
- kubectl yüklü
- GitHub repository oluşturulmuş

## 🔐 1. GitHub Secrets Yapılandırması

GitHub repository'nizde **Settings → Secrets and variables → Actions** bölümüne gidin ve şu secretları ekleyin:

```
AWS_ACCESS_KEY_ID: <AWS Access Key>
AWS_SECRET_ACCESS_KEY: <AWS Secret Key>
```

**ÖNEMLİ:** Bu bilgiler asla repo'ya commit edilmemeli!

## 🏗️ 2. Altyapıyı Oluşturma (Terraform)

### Dev Environment

```bash
cd terraform
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars" -auto-approve
```

### Staging Environment

```bash
terraform workspace new staging  # veya: terraform workspace select staging
terraform apply -var-file="staging.tfvars" -auto-approve
```

### Production Environment

```bash
terraform workspace new prod  # veya: terraform workspace select prod
terraform apply -var-file="prod.tfvars" -auto-approve
```

**Süre:** Her environment için ~15-20 dakika

## 🔄 3. Branch Yapısı ve Deployment

Proje 3 branch üzerinden çalışır:

| Branch   | Environment | Trigger             |
|----------|-------------|---------------------|
| `dev`    | Development | Push to dev branch  |
| `staging`| Staging     | Push to staging     |
| `main`   | Production  | Push to main        |

### İlk Deployment

```bash
# Dev branch'e push
git checkout -b dev
git add .
git commit -m "Initial commit"
git push origin dev

# Staging branch'e push
git checkout -b staging
git push origin staging

# Main branch'e push
git checkout main
git push origin main
```

Her push, GitHub Actions'ı tetikler ve otomatik deployment başlar.

## 🎯 4. Deployment Sonrası Kontrol

### EKS Cluster'a Bağlan

```bash
# Dev environment
aws eks update-kubeconfig --region eu-central-1 --name devops-cicd-dev-cluster

# Namespace'leri kontrol et
kubectl get namespaces

# Pod'ları kontrol et
kubectl get pods -n dev

# Service'i kontrol et (LoadBalancer URL'i al)
kubectl get svc -n dev
```

### Uygulamaya Erişim

LoadBalancer URL'ini al:
```bash
kubectl get svc devops-app-service -n dev -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Tarayıcıdan veya curl ile test et:
```bash
curl http://<LOAD-BALANCER-URL>
```

## 📊 Monitoring

### Logları İzleme

```bash
# Pod logları
kubectl logs -f deployment/devops-app -n dev

# Tüm pod'ların logları
kubectl logs -f -l app=devops-app -n dev
```

### Deployment Durumu

```bash
kubectl get deployments -n dev
kubectl describe deployment devops-app -n dev
```

## 🔧 Troubleshooting

### Image Pull Hatası

```bash
# ECR login kontrol et
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com
```

### Pod Çalışmıyor

```bash
kubectl describe pod <pod-name> -n dev
kubectl logs <pod-name> -n dev
```

### LoadBalancer Hazır Değil

LoadBalancer'ın hazır olması 2-3 dakika sürebilir. Kontrol:
```bash
kubectl get svc devops-app-service -n dev --watch
```

## 🔄 Update Deployment

Kod değişikliği yaptıktan sonra:

```bash
git add .
git commit -m "Update: new feature"
git push origin dev  # veya staging/main
```

GitHub Actions otomatik olarak yeni image'ı build edip deploy eder.

## 📝 Notlar

- Her environment'ın kendi EKS cluster'ı vardır
- Her environment'ın kendi ECR repository'si vardır
- Secrets GitHub Secrets'te güvenli saklanır
- Auto-scaling yapılandırılmıştır (min: 1, max: prod için 3)
