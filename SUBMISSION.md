# Teslim Kılavuzu

## Ne Yapıldı

3 ortamlı CI/CD pipeline. GitHub Actions ile otomatik deployment, AWS EKS üzerinde Kubernetes, Terraform ile infrastructure, Argo CD ile GitOps. Tek komutla kur, tek komutla sil.

## Test Et

```bash
deploy-env.cmd dev              # Kur (~15 dakika)
git push origin dev             # Deploy et (~5 dakika)
kubectl get pods -n dev         # Kontrol et
destroy.cmd dev                 # Sil (mutlaka!)
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
