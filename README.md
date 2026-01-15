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

**Başlat:**
```bash
deploy-env.cmd dev        # ~15 dakika
git push origin dev       # ~5 dakika
```

**Durdur:**
```bash
destroy.cmd dev           # Mutlaka çalıştır yoksa para gider!
```

## Maliyet

Her cluster saatte $0.10 tutuyor. Unutma, kullanmadığında destroy et!

---

**Repository:** https://github.com/mrtylcn99/devops-cicd-project
