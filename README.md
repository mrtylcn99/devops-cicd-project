# DevOps CI/CD Pipeline

Flask uygulaması için AWS EKS üzerinde çalışan otomatik deployment pipeline'ı. 3 ayrı ortam (Dev, Staging, Production) ile tam CI/CD.

## Neler Kullanıldı

- **Uygulama:** Python Flask
- **Container:** Docker + Amazon ECR
- **Kubernetes:** AWS EKS
- **Infrastructure:** Terraform
- **CI/CD:** GitHub Actions
- **GitOps:** Argo CD

## Nasıl Çalışıyor

1. Kodu GitHub'a push'luyorsun
2. GitHub Actions otomatik olarak Docker image build ediyor
3. Image ECR'a upload ediliyor
4. Kubernetes cluster'a deploy ediliyor
5. Uygulama hazır!

Her branch kendi ortamına deploy oluyor:
- `dev` branch → Dev cluster
- `staging` branch → Staging cluster
- `main` branch → Production cluster

## Hızlı Başlangıç

### Gereksinimler

- AWS hesabı (credentials ayarlı)
- Docker Desktop
- Terraform
- kubectl

### 1. Projeyi Kopyala

```bash
git clone https://github.com/mrtylcn99/devops-cicd-project.git
cd devops-cicd-project
```

### 2. GitHub Secrets Ayarla

GitHub repo → Settings → Secrets → Actions'a şunları ekle:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 3. Altyapıyı Kur

**Kolay yol (önerilen):**

```cmd
deploy-env.cmd dev
```

Bu script şunları yapıyor:
- Terraform ile EKS cluster kuruyor
- kubectl'i otomatik ayarlıyor
- Namespace'leri oluşturuyor
- Node'ların hazır olmasını bekliyor

Süre: ~12-15 dakika
Maliyet: Saatte $0.13

**Manuel yol:**

```bash
cd terraform
terraform init
terraform apply -var-file="dev.tfvars"
aws eks update-kubeconfig --region eu-central-1 --name <cluster-adı>
kubectl apply -f k8s/namespace.yaml
```

### 4. Uygulamayı Deploy Et

```bash
git checkout dev
git push origin dev
```

GitHub Actions devreye giriyor ve 5-7 dakikada her şeyi hallediyor.

## Otomasyon Scriptleri

### deploy-env.cmd

İlk kurulum veya destroy sonrası kullan.

```cmd
deploy-env.cmd dev         # Dev ortamı kur
deploy-env.cmd staging     # Staging ortamı kur
```

Ne yapıyor:
1. Terraform init + apply
2. kubectl ayarlarını yapıyor
3. Namespace'leri oluşturuyor
4. Her şeyin hazır olup olmadığını kontrol ediyor

Süre: Her seferinde ~12-15 dakika (ilk seferle aynı)

### destroy.cmd

Test bittikten sonra **mutlaka** çalıştır, yoksa para gider!

```cmd
destroy.cmd dev           # Dev ortamını sil
destroy.cmd staging       # Staging ortamını sil
```

Ne yapıyor:
1. Kubernetes namespace'i ve tüm kaynakları siliyor
2. LoadBalancer'ın silinmesini bekliyor (3 dakika)
3. Terraform destroy ile tüm AWS kaynaklarını kaldırıyor

## Maliyet

Unutursan ağlar! Her EKS cluster saatte $0.10 tutuyor.

| Senaryo | Süre | Maliyet |
|---------|------|---------|
| 2 saatlik test | 2h | ~$0.25 |
| Tüm gün açık | 8h | ~$1.00 |
| Unutup 1 ay | 30 gün | ~$150 |

**Test bitince mutlaka:** `destroy.cmd dev`

## Ortamlar

| Ortam | Branch | Replicas | Instance | Deploy |
|-------|--------|----------|----------|--------|
| Dev | `dev` | 1 | t3.small | Otomatik |
| Staging | `staging` | 1 | t3.small | Otomatik |
| Production | `main` | 2 | t3.medium | Otomatik |

## Yerel Test

```bash
docker build -t devops-app .
docker run -p 5000:5000 -e ENVIRONMENT=dev devops-app
curl http://localhost:5000
```

Çıktı:
```json
{
  "message": "Merhaba! DevOps projene hoş geldin! 🚀",
  "environment": "dev",
  "hostname": "...",
  "status": "healthy",
  "version": "1.0.0"
}
```

## Monitoring

```bash
# Pod'ları kontrol et
kubectl get pods -n dev

# Log'lara bak
kubectl logs -f deployment/devops-app -n dev

# Servis URL'ini al
kubectl get svc devops-app-service -n dev
```

## Sorun Giderme

**Pod başlamıyor:**
```bash
kubectl describe pod <pod-adı> -n dev
kubectl logs <pod-adı> -n dev
```

**LoadBalancer pending:**
2-3 dakika bekle, AWS hazırlıyor. Kontrol:
```bash
kubectl get svc -n dev --watch
```

**Terraform hatası:**
```bash
terraform state list
terraform state rm <sorunlu-kaynak>
terraform apply -var-file="dev.tfvars"
```

## Argo CD (GitOps)

Dev cluster'da kurulu. GitOps tarzı deployment için.

**Erişim:**
- URL: http://a695fd93356ba4669b7707b4aa7e7d5b-421387763.eu-central-1.elb.amazonaws.com
- Kullanıcı: `admin`
- Şifre: `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d`

## Proje Yapısı

```
.
├── app.py                   # Flask uygulaması
├── Dockerfile               # Container tanımı
├── requirements.txt         # Python paketleri
├── deploy-env.cmd          # Kurulum scripti
├── destroy.cmd             # Temizlik scripti
├── terraform/              # Altyapı kodu
│   ├── main.tf            # AWS kaynakları
│   ├── variables.tf       # Değişkenler
│   ├── outputs.tf         # Çıktılar
│   ├── dev.tfvars        # Dev ayarları
│   ├── staging.tfvars    # Staging ayarları
│   └── prod.tfvars       # Prod ayarları
├── k8s/                   # Kubernetes dosyaları
│   ├── namespace.yaml    # Namespace'ler
│   └── deployment.yaml   # Deployment ve Service
├── argocd/               # Argo CD config
│   └── application.yaml
└── .github/workflows/    # CI/CD
    └── cicd.yaml
```

## Güvenlik

- Secret'lar GitHub Secrets'ta (kodda asla yok)
- IAM roller minimum yetkilendirilmiş
- Container resource limitleri var
- Health check'ler aktif

---

**Önemli:** Test bitince `destroy.cmd dev` çalıştırmayı unutma!

**Repository:** https://github.com/mrtylcn99/devops-cicd-project
