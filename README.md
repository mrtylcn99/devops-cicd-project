# DevOps CI/CD Pipeline

AWS EKS üzerinde 3 ortamlı (Dev, Staging, Prod) otomatik deployment sistemi.

## Neler Var

- Python Flask uygulaması
- Docker + Kubernetes (AWS EKS)
- Terraform (Infrastructure as Code)
- GitHub Actions (CI/CD)
- Argo CD (GitOps)

## Nasıl Çalışıyor

Kodu push'la → GitHub Actions build eder → ECR'a yükler → Kubernetes'e deploy eder → Hazır!

## Kullanım

**Hepsini Başlat (Tek Komut):**
```bash
deploy-env.cmd            # 3 ortam birden (~45-60 dakika)
```

**Tek Ortam Başlat:**
```bash
deploy-env.cmd dev
deploy-env.cmd staging
deploy-env.cmd prod        # Sadece biri (~15 dakika)
```

**Durdur:**
```bash
destroy.cmd               # Hepsini sil (~20 dakika)
# VEYA
destroy.cmd dev           # Sadece dev'i sil
destroy.cmd staging       # Sadece staging'i sil
```

## Maliyet

Her cluster saatte $0.10 tutuyor. Unutma, kullanmadığında destroy et!

---

**Repository:** https://github.com/mrtylcn99/devops-cicd-project
