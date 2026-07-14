# Runbook

Commands assume you're in the repo root unless noted. `<...>` is a value
you fill in.

## 0. One-time prerequisites

- AWS account + admin credentials configured locally (`aws configure` or
  SSO)
- An EC2 key pair already created in your target region:
  `aws ec2 create-key-pair --key-name taskapp_key_pair --query 'KeyMaterial' --output text > ~/.ssh/taskapp_key_pair.pem && chmod 400 ~/.ssh/taskapp_key_pair.pem`
- A domain you control, and its registrar's DNS console
- Terraform >= 1.14, Ansible >= 2.16, `kubectl`, `helm` on your workstation
- This repo forked to your own GitHub account (GitOps points at your fork,
  not the upstream template)

See `SETUP_GUIDE.md` for the full, from-nothing workstation walkthrough.

## 1. Provision from zero

```bash
# 1a. Bootstrap the remote state backend (once, ever, per AWS account)
cd terraform/terraform-backend
terraform init
terraform apply
terraform output          # note state_bucket_name / state_lock_table_name

# 1b. Provision the cluster infrastructure
cd ../environments/prod
terraform init             # reads backend.tf - update the bucket name there
                            # first if it doesn't match step 1a's output
terraform apply \
  -var="aws_account_id=<YOUR_ACCOUNT_ID>" \
  -var="admin_ip_cidr=$(curl -s ifconfig.me)/32" \
  -var="state_bucket_name=<FROM_1a>" \
  -var="lock_table_name=<FROM_1a>" \
  -var="github_org=<YOUR_GH_USERNAME>" \
  -var="github_infra_repo=<YOUR_FORK_NAME>"

terraform output           # bastion_public_ip, k3s_master_private_ip,
                            # k3s_worker_private_ips, nlb_dns_name
```

Point your domain's DNS at `nlb_dns_name` now (CNAME, or your registrar's
flattened-CNAME/ALIAS record if it's the apex) - it takes time to
propagate, so start this before step 3.

## 2. Populate the Ansible inventory

Copy the Terraform outputs into `ansible/inventory/prod.yaml`, replacing
every `<TERRAFORM_OUTPUT_...>` placeholder.

```bash
cd ansible
cp inventory/group_vars/all/vault.yaml.example inventory/group_vars/all/vault.yaml
$EDITOR inventory/group_vars/all/vault.yaml    # real admin CIDR + passwords
ansible-vault encrypt inventory/group_vars/all/vault.yaml
echo '<a vault password>' > .vault_pass && chmod 600 .vault_pass

ansible-galaxy collection install -r requirements.yml
```

Also edit `inventory/group_vars/all/vars.yaml`: set `app_domain`,
`letsencrypt_email`, and `taskapp_gitops_repo_url` to your real values.

## 3. Bring up the cluster

```bash
ansible-playbook playbooks/site.yaml
```

**Acceptance check:**
```bash
# 6443 is never public - open a local tunnel through the bastion first
# (see SETUP_GUIDE.md §6), leave it running in another terminal:
ssh -L 6443:<k3s_master_private_ip>:6443 taskapp-bastion -N

export KUBECONFIG=$(pwd)/../kubeconfig-taskapp-prod
kubectl get nodes
# NAME             STATUS   ROLES                  AGE   VERSION
# k3s-master-01    Ready    control-plane,master   2m    v1.29.4+k3s1
# k3s-worker-01    Ready    <none>                 90s   v1.29.4+k3s1
# k3s-worker-02    Ready    <none>                 90s   v1.29.4+k3s1
```

Idempotency check: run `ansible-playbook playbooks/site.yaml` a second
time - it should report `changed=0` for every host.

## 4. Install the platform and bootstrap GitOps

```bash
# First, push gitops/taskapp/ (with your real domain edited into
# 60-ingress.yaml) to your fork's main branch - Argo CD needs something
# to sync the moment it's installed.
git add gitops/ && git commit -m "gitops: set real domain" && git push

ansible-playbook playbooks/deploy_gitops.yaml
```

This installs ingress-nginx, cert-manager (+ ClusterIssuer), metrics-
server, kube-prometheus-stack, and Argo CD, then applies the one root
`Application` that hands the app itself to Argo CD.

**Acceptance checks:**
```bash
kubectl -n argocd get application taskapp
# SYNC STATUS   HEALTH STATUS
# Synced        Healthy

curl -vI https://<your-domain>/
# HTTP/2 200, and a certificate issued by Let's Encrypt (check with
# openssl s_client -connect <your-domain>:443 -servername <your-domain>
# </dev/null 2>/dev/null | openssl x509 -noout -issuer)
```

## 5. Day-2 operations

**Deploy a new app version:**
```bash
# Bump the image tag(s) in gitops/taskapp/30-backend.yaml and/or
# 40-frontend.yaml to the new commit SHA, then:
git add gitops/ && git commit -m "deploy: bump backend to <sha>" && git push
# Argo CD syncs automatically within its poll interval, or force it now:
kubectl -n argocd patch application taskapp --type merge -p '{"operation":{"sync":{}}}'
```

**Scale the backend manually (outside the HPA):**
```bash
# Edit replicas: in gitops/taskapp/30-backend.yaml, commit, push.
# Don't `kubectl scale` directly - selfHeal will revert it within seconds.
```

**Roll back a bad deploy:**
```bash
git revert <bad-commit-sha> && git push
# or, from the Argo CD UI/CLI: pick a prior synced revision and
# `argocd app rollback taskapp <history-id>`
```

**Rotate the DB password:**
```bash
ansible-vault edit inventory/group_vars/all/vault.yaml   # update vault_postgres_password
ansible-playbook playbooks/deploy_gitops.yaml            # re-applies the Secret
kubectl -n taskapp rollout restart deployment/backend statefulset/postgres
```

## 6. Failure recovery

**A worker node dies:**
The other worker keeps serving (PDB + 2 replicas + spread constraints).
Terraform will show a plan to replace the dead instance:
```bash
cd terraform/environments/prod && terraform apply
```
Then re-run `ansible-playbook playbooks/site.yaml` (idempotent - only
touches the new node) and update the NLB target group by re-applying
Terraform again (the `nlb` module reads instance IDs from `module.ec2`,
so a `terraform apply` after the replacement re-registers the new
instance automatically).

**A backend Pod dies:**
Kubernetes restarts it automatically (Deployment controller). If it
keeps crash-looping: `kubectl -n taskapp logs deploy/backend --previous`.

**A bad migration:**
The migration Job's `backoffLimit: 3` means it retries 3 times, then
Argo CD reports the sync as failed and does **not** proceed to wave 0 -
the old backend/frontend Pods keep serving on the old schema, nothing
switches over broken. Fix: revert the migration in a new commit, or
`kubectl -n taskapp logs job/taskapp-db-migration` to see why it failed,
fix forward, push again.

## 7. Live failover demo checklist

```bash
kubectl get pods -n taskapp -o wide          # note which node each backend Pod is on
kubectl drain <that-node-name> --ignore-daemonsets --delete-emptydir-data
watch kubectl get pods -n taskapp -o wide    # Pod reschedules to the other worker
curl -o /dev/null -s -w "%{http_code}\n" https://<your-domain>/   # still 200 throughout
kubectl uncordon <that-node-name>            # bring it back
```
