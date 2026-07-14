# capstone-phoenix — TaskApp on Kubernetes

TaskApp running on a self-provisioned, multi-node k3s cluster: HA,
autoscaling, zero-downtime deploys, real TLS on a real domain, fully
GitOps-reconciled.

## Start here

- **First time setting this up?** → `SETUP_GUIDE.md`
- **Day-2 operations, scaling, rollback, failure recovery?** → `docs/RUNBOOK.md`
- **How it fits together, and why?** → `docs/ARCHITECTURE.md`
- **What this costs?** → `docs/COST.md`

## Repo layout

```
terraform/
  terraform-backend/   bootstrap: S3 state bucket + DynamoDB lock table (run once, local state)
  modules/              core, vpc, security_groups, ec2, nlb, iam - reusable building blocks
  environments/prod/    the actual cluster infra: 1 bastion + 1 k3s master + 2+ k3s workers + NLB

ansible/
  playbooks/site.yaml          base hardening -> bastion hardening -> k3s server+agent bring-up
  playbooks/deploy_gitops.yaml platform install (ingress-nginx, cert-manager, metrics-server,
                                kube-prometheus-stack, Argo CD) + GitOps bootstrap - master only
  roles/                        common, bastion, k3s, k3s_platform
  inventory/                    prod / staging / dev, group_vars (vault.yaml.example → vault.yaml)

gitops/taskapp/       everything Argo CD owns: Namespace, ConfigMap, Postgres StatefulSet+PVC,
                       migration Job, backend/frontend Deployments, HPA, PDB, NetworkPolicy, Ingress+TLS
                       - edit here, commit, push; nobody runs kubectl apply against this by hand

docs/                  ARCHITECTURE.md, RUNBOOK.md, COST.md, EVIDENCE/ (screenshots/logs)
cicd/.github/workflows/ ansible syntax-check + lint, gitops manifest lint, terraform fmt check
```

## What changed from the original single-server (Portainer) deploy

Everything - that's the point of this capstone. The short version: one
EC2 instance running Docker Compose became a 3-node k3s cluster with the
Postgres data on a `StatefulSet` + `PVC` instead of a bind mount, 2+
replicas per tier spread across real separate machines, migrations as an
ordered `Job` instead of racing in the container entrypoint, a real
Let's Encrypt certificate instead of Portainer's self-signed default, and
Argo CD reconciling the desired state from git instead of a push-to-
redeploy webhook. `docs/ARCHITECTURE.md` has a full requirement-by-
requirement breakdown of which single-server assumption each change
fixes.
