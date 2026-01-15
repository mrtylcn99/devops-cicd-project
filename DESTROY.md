# ⚠️ TERRAFORM DESTROY REHBERİ

## 🚨 ÇOK ÖNEMLİ - OKUMADAN GEÇMEYİN!

AWS EKS **saatte ~$0.10** ücretlendirir. Bu ayda **~$72** demektir.
Worker node'lar (EC2) için ek **~$50-75/ay** daha.

**TOPLAM: ~$150/ay** sürekli açık kalırsa! 💸

## ✅ Ne Zaman Destroy Yapmalısınız?

- ✅ Test/demo bittikten sonra **HEMEN**
- ✅ Gece yatmadan önce
- ✅ Hafta sonu kullanmayacaksanız
- ✅ Öğrenme amaçlı kullanıyorsanız, her oturumdan sonra

## 📝 Destroy Yapma Adımları

### 1. ÖNCE Kubernetes Kaynaklarını Temizleyin

**NEDEN?** LoadBalancer gibi kaynaklar AWS'de kalmaya devam eder ve Terraform onları silemez.

```bash
# Her environment için tekrarlayın (dev, staging, prod)

# Dev için:
aws eks update-kubeconfig --region eu-central-1 --name devops-cicd-dev-cluster
kubectl delete namespace dev --force --grace-period=0

# Staging için:
aws eks update-kubeconfig --region eu-central-1 --name devops-cicd-staging-cluster
kubectl delete namespace staging --force --grace-period=0

# Prod için:
aws eks update-kubeconfig --region eu-central-1 --name devops-cicd-prod-cluster
kubectl delete namespace prod --force --grace-period=0
```

**Bekleyin:** LoadBalancer'ların silinmesi 2-3 dakika sürebilir.

### 2. Terraform Destroy

```bash
cd terraform

# Dev environment
terraform destroy -var-file="dev.tfvars" -auto-approve

# Staging environment (eğer oluşturduysanız)
terraform workspace select staging
terraform destroy -var-file="staging.tfvars" -auto-approve

# Prod environment (eğer oluşturduysanız)
terraform workspace select prod
terraform destroy -var-file="prod.tfvars" -auto-approve
```

**Süre:** Environment başına ~10-15 dakika

### 3. Manuel Kontrol (Opsiyonel ama Önerilen)

AWS Console'a girin ve şunları kontrol edin:

#### EKS
```
Services → Elastic Kubernetes Service → Clusters
```
**Sonuç:** Cluster listesi boş olmalı

#### EC2
```
Services → EC2 → Instances
```
**Sonuç:** EKS node'ları silinmiş olmalı

#### Load Balancers
```
Services → EC2 → Load Balancers
```
**Sonuç:** EKS için oluşturulan LB'ler silinmiş olmalı

#### ECR (Container Registry)
```
Services → ECR → Repositories
```
**Sonuç:** Repository'ler silinmiş olmalı

### 4. Maliyet Kontrolü

AWS Console → Billing → Bills bölümünden **son 24 saat** kullanımını kontrol edin.

**Normal kullanım (2-3 saat test):**
- EKS: ~$0.30
- EC2: ~$0.15
- **TOPLAM: ~$0.50** ✅

**Unutulan cluster (1 hafta):**
- EKS: ~$17
- EC2: ~$12
- **TOPLAM: ~$30** ❌

## 🛡️ Destroy Hatası Durumunda

### Hata: "Resources still exist"

```bash
# Tüm Kubernetes kaynaklarını zorla sil
kubectl delete all --all -n dev --force --grace-period=0
kubectl delete all --all -n staging --force --grace-period=0
kubectl delete all --all -n prod --force --grace-period=0

# Tekrar dene
terraform destroy -var-file="dev.tfvars" -auto-approve
```

### Hata: "LoadBalancer still deleting"

Kubernetes'in LoadBalancer'ı silmesini bekleyin (AWS Console'dan kontrol):
```
EC2 → Load Balancers → Deleting durumunu bekleyin
```

### En Son Çare: Manuel Silme

1. AWS Console → EKS → Cluster seç → Delete
2. EC2 → Instances → EKS node'larını seç → Terminate
3. EC2 → Load Balancers → Delete
4. ECR → Repository → Delete

## 🎯 Hızlı Destroy Script (Hepsi Birden)

Aşağıdaki scripti `destroy-all.sh` olarak kaydedin:

```bash
#!/bin/bash

echo "🚨 TÜM ENVIRONMENT'LARI SİLİYORUZ!"
echo "10 saniye içinde durdurmak için Ctrl+C basın..."
sleep 10

# Kubernetes kaynaklarını sil
for ENV in dev staging prod; do
  echo "Deleting $ENV namespace..."
  aws eks update-kubeconfig --region eu-central-1 --name devops-cicd-$ENV-cluster 2>/dev/null
  kubectl delete namespace $ENV --force --grace-period=0 2>/dev/null
done

echo "Waiting for LoadBalancers to be deleted..."
sleep 60

# Terraform destroy
cd terraform
for ENV in dev staging prod; do
  echo "Destroying $ENV infrastructure..."
  terraform workspace select $ENV 2>/dev/null || terraform workspace new $ENV
  terraform destroy -var-file="$ENV.tfvars" -auto-approve
done

echo "✅ Tüm kaynaklar silindi!"
echo "AWS Console'dan kontrol etmeyi unutmayın."
```

## 📊 Maliyet Takibi

### Günlük Kontrol

```bash
# Bugünkü tahmini maliyeti göster
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "yesterday" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics "UnblendedCost" \
  --group-by Type=SERVICE
```

### AWS Budget Alarmı Kur

1. AWS Console → Billing → Budgets
2. Create budget → Cost budget
3. Set budget: **$10/ay**
4. Alert: **$5'a ulaşınca email at**

## ✅ Checklist

Destroy yapmadan önce bu listeyi kontrol edin:

- [ ] Tüm Kubernetes namespace'leri silindi
- [ ] LoadBalancer'lar tamamen silindi (AWS Console kontrol)
- [ ] `terraform destroy` başarıyla tamamlandı
- [ ] AWS Console'da EKS cluster'ları yok
- [ ] EC2 instance'ları yok
- [ ] ECR repository'leri silindi
- [ ] Billing Dashboard'da son kullanım kontrol edildi

## 🎓 Öğrendiklerimiz

- AWS kaynakları **saat bazında** ücretlendirilir
- Kullanmadığın kaynaklara **para ödersin**
- **Terraform destroy** altyapıyı tek komutla siler
- **Otomasyonun gücü:** Manuel silmekten çok daha kolay!

---

**HATIRLATMA:** Bu bir öğrenme projesi. Gerçek production'da:
- Reserved Instances ile %60 indirim alırsın
- Spot Instances ile %90 indirim alırsın
- Auto-shutdown politikaları kurarsın

Ama şimdilik: **Kullan, öğren, destroy et!** 🚀
