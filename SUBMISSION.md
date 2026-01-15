# Teslim Kılavuzu

## Ne Yapıldı

3 ortamlı CI/CD pipeline. GitHub Actions ile otomatik deployment, AWS EKS üzerinde Kubernetes, Terraform ile infrastructure, Argo CD ile GitOps. Tek komutla kur, tek komutla sil.

## Test Et

**Hızlı test (tek ortam):**
```bash
deploy-env.cmd dev              # Kur (~15 dakika)
git push origin dev             # Deploy et (~5 dakika)
kubectl get pods -n dev         # Kontrol et
destroy.cmd dev                 # Sil (mutlaka!)
```

**Tam test (3 ortam):**
```bash
deploy-env.cmd                  # Hepsini kur (~45-60 dakika)
git push origin dev
git push origin staging
git push origin main
destroy.cmd dev                 # Hepsini sil
destroy.cmd staging
destroy.cmd prod
```

## Ne Paylaş

Sadece bunu:
```
https://github.com/mrtylcn99/devops-cicd-project

3 ortamlı CI/CD pipeline hazır. GitHub Actions + AWS EKS + Terraform + Argo CD.
README'ye bak.
```

## Önemli

⚠️ Test bitince MUTLAKA `destroy.cmd dev` çalıştır, yoksa saatte $0.10 gider!

⚠️ Deploy her seferinde ~15 dakika alır (ilk sefer de, destroy sonrası da aynı).

---

**Hazır!** → https://github.com/mrtylcn99/devops-cicd-project
