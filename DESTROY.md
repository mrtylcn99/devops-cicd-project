# Infrastructure Cleanup Guide

## Quick Cleanup

**Windows:**
```cmd
destroy.cmd dev
```

**Linux/Mac:**
```bash
./destroy.sh dev
```

## Manual Cleanup

If automated scripts fail:

```bash
# 1. Delete Kubernetes resources
kubectl delete namespace dev --force --grace-period=0

# 2. Wait for LoadBalancer deletion (2-3 minutes)
sleep 180

# 3. Destroy Terraform infrastructure
cd terraform
terraform destroy -var-file="dev.tfvars" -auto-approve
```

## Cost Warning

**EKS Cluster:** $0.10/hour = $72/month if forgotten

| Duration | Cost |
|----------|------|
| 2 hours  | $0.25 |
| 1 day    | $2.40 |
| 1 week   | $30 |
| 1 month  | $150 |

## Verification

After cleanup, verify in AWS Console:

1. **EKS:** No clusters exist
2. **EC2:** No instances running
3. **Load Balancers:** All deleted
4. **ECR:** Repositories removed

Check AWS bill after 24 hours to confirm zero usage.

## Troubleshooting

**LoadBalancer still exists:**
```bash
# Wait longer and retry
sleep 120
terraform destroy -var-file="dev.tfvars" -auto-approve
```

**Terraform state issues:**
```bash
terraform state list
terraform state rm <stuck-resource>
terraform destroy -var-file="dev.tfvars" -auto-approve
```

**Last resort - Manual deletion:**
1. AWS Console → EKS → Delete cluster
2. EC2 → Terminate instances
3. EC2 → Load Balancers → Delete
4. ECR → Delete repositories

---

⚠️ **Always destroy after testing to avoid unnecessary costs!**
