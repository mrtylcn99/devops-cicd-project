# 🚀 DevOps CI/CD Projesi

Modern DevOps pratiklerini uygulayan, production-ready CI/CD pipeline projesi.

## 🎯 Proje Hedefi

Basit bir Flask web uygulamasını **3 farklı ortama** (Dev, Staging, Prod) **tamamen otomatik** olarak deploy etmek.

## ✨ Özellikler

- ✅ **3 İzole Environment:** Dev, Staging, Production
- ✅ **Tam Otomatik CI/CD:** GitHub Actions ile push-to-deploy
- ✅ **Infrastructure as Code:** Terraform ile altyapı yönetimi
- ✅ **Container Orchestration:** AWS EKS (Kubernetes)
- ✅ **Güvenli Secret Management:** GitHub Secrets entegrasyonu
- ✅ **Health Checks:** Otomatik sağlık kontrolü ve rollback
- ✅ **Auto Scaling:** Trafiğe göre otomatik ölçeklendirme
- ✅ **Maliyet Optimizasyonu:** Tek komutla tüm altyapıyı yok et

## 🛠️ Teknoloji Stack

| Kategori | Teknoloji |
|----------|-----------|
| **Uygulama** | Python Flask + Gunicorn |
| **Konteyner** | Docker + Amazon ECR |
| **Orkestrasyon** | Kubernetes (AWS EKS) |
| **Altyapı** | Terraform |
| **CI/CD** | GitHub Actions |
| **Cloud** | AWS (EKS, EC2, ECR, IAM) |
| **Secret Management** | GitHub Secrets |

## 📁 Proje Yapısı

```
.
├── app.py                      # Flask uygulaması
├── requirements.txt            # Python dependencies
├── Dockerfile                  # Container image tanımı
├── .dockerignore
├── .gitignore
│
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                # AWS resources (EKS, ECR, IAM)
│   ├── variables.tf           # Değişken tanımları
│   ├── outputs.tf             # Terraform çıktıları
│   ├── dev.tfvars             # Dev environment variables
│   ├── staging.tfvars         # Staging environment variables
│   └── prod.tfvars            # Prod environment variables
│
├── k8s/                       # Kubernetes manifests
│   ├── namespace.yaml         # 3 environment namespace
│   └── deployment.yaml        # Deployment + Service
│
├── .github/workflows/
│   └── cicd.yaml              # CI/CD pipeline
│
├── DEPLOYMENT.md              # Deployment rehberi
├── DESTROY.md                 # ⚠️ Maliyet yönetimi (ÖNEMLİ!)
└── README.md                  # Bu dosya
```

## 🚀 Hızlı Başlangıç

### 1️⃣ Lokal Test (Docker ile)

```bash
# Image build et
docker build -t devops-app:latest .

# Çalıştır
docker run -d -p 5000:5000 -e ENVIRONMENT=dev devops-app:latest

# Test et
curl http://localhost:5000
```

**Beklenen Response:**
```json
{
  "message": "Merhaba! DevOps projene hoş geldin!",
  "environment": "dev",
  "hostname": "container-id",
  "status": "healthy"
}
```

### 2️⃣ AWS'ye Deploy

**Detaylı adımlar için:** [DEPLOYMENT.md](DEPLOYMENT.md) dosyasına bakın.

**Kısa özet:**

1. **GitHub Secrets ekle:**
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

2. **Terraform ile altyapıyı kur:**
   ```bash
   cd terraform
   terraform init
   terraform apply -var-file="dev.tfvars"
   ```

3. **Kodu GitHub'a push et:**
   ```bash
   git push origin dev      # Dev'e deploy
   git push origin staging  # Staging'e deploy
   git push origin main     # Production'a deploy
   ```

4. **GitHub Actions otomatik çalışır!** 🎉

## 🌍 Environment Yapısı

| Environment | Branch | Replicas | Instance Type | Auto Deploy |
|-------------|--------|----------|---------------|-------------|
| **Dev** | `dev` | 1 | t3.small | ✅ |
| **Staging** | `staging` | 1 | t3.small | ✅ |
| **Prod** | `main` | 2 | t3.medium | ✅ |

## 🔄 CI/CD Pipeline Akışı

```
Developer Push Code
       ↓
GitHub Actions Trigger
       ↓
Build Docker Image
       ↓
Push to Amazon ECR
       ↓
Update Kubeconfig
       ↓
Deploy to EKS Cluster
       ↓
Health Check
       ↓
Get LoadBalancer URL
       ↓
✅ DONE!
```

**Süre:** ~5-7 dakika

## 💰 Maliyet Yönetimi

### ⚠️ ÇOK ÖNEMLİ!

AWS EKS **saatte $0.10** ücret alır → **Ayda ~$72**

**Çözüm:** İş bitince hemen `terraform destroy` yap!

```bash
# Önce Kubernetes kaynaklarını sil
kubectl delete namespace dev --force

# Sonra Terraform destroy
cd terraform
terraform destroy -var-file="dev.tfvars" -auto-approve
```

**Detaylı talimatlar:** [DESTROY.md](DESTROY.md) ⚠️ **OKUMADAN GEÇMEYİN!**

### Tahmini Maliyetler

| Senaryo | Süre | Maliyet |
|---------|------|---------|
| **2 saat test** | 2h | ~$0.50 |
| **1 gün** | 24h | ~$2.40 |
| **1 hafta (unutulmuş)** | 7d | ~$30 💸 |
| **1 ay (unutulmuş)** | 30d | ~$150 💸💸💸 |

## 🧪 Test Senaryoları

### Manuel Test

```bash
# Pod'ları kontrol et
kubectl get pods -n dev

# Logları izle
kubectl logs -f deployment/devops-app -n dev

# Service URL'i al
kubectl get svc devops-app-service -n dev

# Health check
curl http://<LOAD-BALANCER-URL>/health
```

### Otomatik Test

Pipeline içinde otomatik:
- ✅ Docker build test
- ✅ Container health check
- ✅ Kubernetes deployment verification
- ✅ Rollout status check

## 📊 Monitoring

```bash
# Real-time pod durumu
kubectl get pods -n dev --watch

# Resource kullanımı
kubectl top pods -n dev

# Deployment detayları
kubectl describe deployment devops-app -n dev
```

## 🔐 Security Best Practices

✅ **Yapılanlar:**
- Secrets asla repo'ya commit edilmez (`.gitignore`)
- GitHub Secrets ile güvenli saklama
- IAM roles ile minimum privilege
- ECR image scanning aktif
- Resource limits (CPU, Memory)

❌ **Yapılmaması gerekenler:**
- AWS credentials'ı kod içine yazmak
- `.env` dosyasını commit etmek
- Root user ile çalışmak

## 🐛 Troubleshooting

### Problem: Image pull hatası

```bash
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com
```

### Problem: Pod çalışmıyor

```bash
kubectl describe pod <pod-name> -n dev
kubectl logs <pod-name> -n dev
```

### Problem: Terraform hata veriyor

```bash
# State'i kontrol et
terraform state list

# Problematic resource'u kaldır
terraform state rm <resource>

# Tekrar dene
terraform apply
```

## 📚 Öğrendiklerimiz

- ✅ Docker containerization
- ✅ Kubernetes orchestration
- ✅ Infrastructure as Code (Terraform)
- ✅ CI/CD automation (GitHub Actions)
- ✅ AWS cloud services (EKS, ECR, IAM)
- ✅ Secret management
- ✅ Multi-environment deployment
- ✅ Cost optimization

## 🎯 Gelecek İyileştirmeler

- [ ] Argo CD entegrasyonu (GitOps)
- [ ] Prometheus + Grafana monitoring
- [ ] Helm Charts
- [ ] Blue-Green deployment
- [ ] Automated testing (pytest)
- [ ] SSL/TLS (HTTPS)

## 📞 İletişim

**GitHub:** [@mrtylcn99](https://github.com/mrtylcn99)

## 📄 Lisans

Bu proje eğitim amaçlıdır ve serbestçe kullanılabilir.

---

⭐ **Projeyi beğendiysen yıldız vermeyi unutma!**
