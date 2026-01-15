# Proje Teslim Kılavuzu

## Ne Yapıldı

DevOps ödevini tamamladım. Şunlar var:

✅ **CI/CD Pipeline** - GitHub Actions ile otomatik deployment
✅ **3 Ortam** - Dev, Staging, Production (hepsi ayrı cluster'da)
✅ **AWS EKS** - Kubernetes cluster'lar Terraform ile kurulu
✅ **GitOps** - Argo CD kurulu ve çalışıyor
✅ **Güvenlik** - Secret'lar GitHub Secrets'ta, kodda yok
✅ **Otomasyon** - Tek komutla kur, tek komutla sil

## Projenin Özeti

3 ayrı Kubernetes cluster'ı var (dev, staging, prod). Her ortam için ayrı ayarlar.

Kod push'ladığında:
1. GitHub Actions devreye giriyor
2. Docker image build ediliyor
3. Amazon ECR'a yükleniyor
4. Kubernetes'e deploy ediliyor
5. Health check'lerden geçiyor
6. Hazır!

Branch'e göre deployment:
- `dev` → Dev cluster
- `staging` → Staging cluster
- `main` → Production cluster

## Nasıl Test Edilir

### Hızlı Test (15 dakika)

```bash
# 1. Cluster'ı kur
deploy-env.cmd dev

# 2. Uygulamayı deploy et
git push origin dev

# 3. Kontrol et
kubectl get pods -n dev
kubectl get svc devops-app-service -n dev

# 4. Argo CD'ye bak
# URL: http://a695fd93356ba4669b7707b4aa7e7d5b-421387763.eu-central-1.elb.amazonaws.com
# Kullanıcı: admin
# Şifre: kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d

# 5. MUTLAKA temizle (yoksa para gider!)
destroy.cmd dev
```

### Tam Test (3 Ortam)

```bash
# Hepsini kur
deploy-env.cmd dev
deploy-env.cmd staging
deploy-env.cmd prod

# Deploy et
git push origin dev
git push origin staging
git push origin main

# Kontrol et
kubectl get pods --all-namespaces

# MUTLAKA hepsini temizle
destroy.cmd dev
destroy.cmd staging
destroy.cmd prod
```

## Ne Paylaşılacak

**Repository:**
```
https://github.com/mrtylcn99/devops-cicd-project
```

**Söylenecekler:**
- 3 ortamlı CI/CD pipeline hazır
- GitHub Actions ile otomatik deployment çalışıyor
- AWS EKS üzerinde Kubernetes
- Terraform ile Infrastructure as Code
- Argo CD ile GitOps kurulu
- Tek komutla kur, tek komutla sil scriptleri var

**Opsiyonel (göstermek istersen):**
- Çalışan uygulamanın URL'i
- GitHub Actions workflow'unun başarılı çalıştığı ekran görüntüsü
- kubectl get pods çıktısı
- Argo CD UI screenshot'u

## Önemli Bilgiler

### Dosya Yapısı

```
.
├── app.py                  # Flask uygulaması
├── Dockerfile              # Container
├── requirements.txt        # Python paketleri
├── deploy-env.cmd         # Kurulum scripti
├── destroy.cmd            # Temizlik scripti
├── terraform/             # Altyapı kodu (11 AWS kaynağı)
├── k8s/                   # Kubernetes manifest'leri
├── argocd/                # Argo CD config
└── .github/workflows/     # CI/CD pipeline
```

### Özellikler

**Otomasyonlar:**
- `deploy-env.cmd dev` → 15 dakikada cluster hazır
- `git push` → 5-7 dakikada uygulama deploy
- `destroy.cmd dev` → Her şeyi temizle

**Production-Ready:**
- Health check'ler var
- Resource limitleri ayarlı
- Otomatik rollback
- Multi-environment isolation

**Maliyet Kontrolü:**
- Her cluster: $0.10/saat = $72/ay
- 3 cluster çalışırsa: ~$216/ay
- **Mutlaka destroy et!**

### Scriptler

**deploy-env.cmd** - İlk kurulum veya destroy sonrası
- Terraform ile infrastructure kuruyor
- kubectl ayarlarını yapıyor
- Namespace'leri oluşturuyor
- Her seferinde ~12-15 dakika sürüyor (ilk sefer de, destroy sonrası da aynı)

**destroy.cmd** - Test bitince MUTLAKA çalıştır
- Kubernetes kaynaklarını siliyor
- LoadBalancer'ın kapanmasını bekliyor
- Terraform destroy ile her şeyi kaldırıyor
- ~5-7 dakika

### Deploy → Destroy → Deploy Döngüsü

```bash
# İlk kurulum
deploy-env.cmd dev          # ~15 dakika

# Test et
git push origin dev         # ~5-7 dakika
kubectl get pods -n dev

# Temizle
destroy.cmd dev            # ~5-7 dakika

# Tekrar kurmak istersen
deploy-env.cmd dev          # Yine ~15 dakika (aynı süre!)
```

**Önemli:** Destroy sonrası tekrar kurarken yine aynı süre geçiyor çünkü:
- EKS cluster'ı sıfırdan kuruluyor
- Node'lar yeniden başlatılıyor
- AWS kaynakları tekrar oluşturuluyor

İlk seferle destroy sonrası kurulum arasında fark yok, her ikisi de ~12-15 dakika.

## Sorun Çıkarsa

### GitHub Actions hatası
- Actions sekmesinden log'lara bak
- Genelde secret eksikliği veya AWS yetki sorunu

### Deployment hatası
```bash
kubectl get pods -n dev
kubectl describe pod <pod-adı> -n dev
kubectl logs <pod-adı> -n dev
```

### Terraform hatası
```bash
cd terraform
terraform state list
terraform state rm <sorunlu-kaynak>
terraform apply -var-file="dev.tfvars"
```

### Destroy çalışmıyor
```bash
# Manuel temizlik
kubectl delete namespace dev --force --grace-period=0
sleep 180
cd terraform
terraform destroy -var-file="dev.tfvars" -auto-approve
```

### AWS Console'dan kontrol
- EKS → Cluster'lar listesi boş olmalı
- EC2 → Instance'lar yok olmalı
- EC2 → Load Balancers temiz olmalı

## Teslim Öncesi Checklist

Arkadaşına vermeden önce kontrol et:

- [ ] Deploy → destroy döngüsü çalışıyor mu test et
- [ ] GitHub Actions başarıyla çalışıyor mu kontrol et
- [ ] README açık ve anlaşılır mı oku
- [ ] Bütün cluster'ları destroy et (para gitmesin!)
- [ ] Gerekirse screenshot al

## Teslim Sonrası

- AWS faturasını takip et (0 olmalı)
- Repository public kalsın
- Demo isterse hazır ol

## Önemli Uyarılar

⚠️ **PARA GİDER:** Test bitince MUTLAKA destroy et!
- Her cluster: $0.10/saat
- 3 cluster: ~$216/ay
- Unutursan fatura gelir!

⚠️ **HER DESTROY SONRASI AYNI SÜRE:** Deploy tekrar ~15 dakika alıyor

⚠️ **AWS SECRETS:** Asla koda koyma, GitHub Secrets kullan

## Sorularına Cevaplar

**Infrastructure nasıl çalışıyor?**
→ `terraform/` klasörüne bak, her şey orada

**CI/CD nasıl çalışıyor?**
→ `.github/workflows/cicd.yaml` dosyasına bak

**Uygulama ne yapıyor?**
→ `app.py` ve `Dockerfile`'a bak

**Deployment nasıl oluyor?**
→ `deploy-env.cmd` ve `destroy.cmd` scriptlerine bak

---

**Durum:** ✅ Hazır, teslim edilebilir

**Repository:** https://github.com/mrtylcn99/devops-cicd-project

**Yapan:** Mert Yalçın (@mrtylcn99)
