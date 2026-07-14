# Workstation Setup Guide

Everything you need installed locally, in order, to go from a clean
machine to a working cluster you can `kubectl get nodes` against.

## 1. Install the CLI tools

macOS (Homebrew):
```bash
brew install terraform ansible awscli kubectl helm
```

Ubuntu/Debian:
```bash
sudo apt update
sudo apt install -y unzip curl python3-pip

# Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

# AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Ansible
pip install --user ansible ansible-lint
```

Windows: use WSL2 (Ubuntu) and follow the Ubuntu steps above - none of
this tooling has a great native Windows story, and the ProxyJump SSH
config below assumes an OpenSSH client that behaves like Linux/macOS's.

Confirm everything's on your PATH:
```bash
terraform version && ansible --version && aws --version && kubectl version --client && helm version
```

## 2. AWS account access

```bash
aws configure
# AWS Access Key ID, Secret Access Key, default region (eu-north-1 unless
# you changed it), default output format (json)
aws sts get-caller-identity     # confirms it worked, prints your account ID - save this, you need it later
```

## 3. SSH key pair

```bash
aws ec2 create-key-pair --key-name taskapp_key_pair \
  --query 'KeyMaterial' --output text > ~/.ssh/taskapp_key_pair.pem
chmod 400 ~/.ssh/taskapp_key_pair.pem
```

## 4. Fork and clone this repo

Fork `capstone-phoenix` to your own GitHub account first (GitOps needs to
point at a repo you control) - **not** a clone of the upstream, an actual
GitHub fork - then:

```bash
git clone git@github.com:<you>/capstone-phoenix.git
cd capstone-phoenix
```

## 5. Provision + configure

Follow `docs/RUNBOOK.md` sections 1-4 from here - it has the exact
`terraform apply` and `ansible-playbook` commands. Come back to this
guide for step 6 once `kubectl get nodes` and `curl https://<your-domain>/`
both work.

## 6. Set up your local `kubectl`/Argo CD/Grafana access

The k3s API and the in-cluster UIs (Argo CD, Grafana) are never exposed
to the internet - you always reach them through the bastion. Two ways to
do that:

**Option A - SSH config with ProxyJump (recommended, set up once):**

Add to `~/.ssh/config`:
```
Host taskapp-bastion
  HostName <bastion_public_ip>
  User ubuntu
  IdentityFile ~/.ssh/taskapp_key_pair.pem

Host taskapp-k3s-master
  HostName <k3s_master_private_ip>
  User ubuntu
  IdentityFile ~/.ssh/taskapp_key_pair.pem
  ProxyJump taskapp-bastion
```

Then:
```bash
ssh taskapp-k3s-master     # just works, hops through the bastion transparently
```

`playbooks/site.yaml` fetches the kubeconfig to `kubeconfig-taskapp-prod`
in the repo root, deliberately left pointed at `https://127.0.0.1:6443` -
6443 is never public, so `kubectl` always needs an explicit local
port-forward through the bastion first:

```bash
ssh -L 6443:<k3s_master_private_ip>:6443 taskapp-bastion -N &   # leave running in the background

export KUBECONFIG=$(pwd)/kubeconfig-taskapp-prod
kubectl get nodes
```

(Kill the background tunnel with `kill %1` or `fg` + Ctrl-C when you're
done. If you'd rather not manage a background job, run the `ssh -L ...`
command in its own terminal tab without `-N &` and just leave it open.)

**Option B - manual port-forward, for the web UIs specifically:**

```bash
# Argo CD UI
kubectl -n argocd port-forward svc/argocd-server 8080:443
# open https://localhost:8080 - username admin, password:
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

# Grafana
kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
# open http://localhost:3000 - username admin, password is
# vault_grafana_admin_password from your vault.yaml
```

## 7. Sanity checklist before you consider this "done"

```bash
kubectl get nodes                                   # 3 nodes, all Ready
kubectl -n taskapp get pods -o wide                  # 2 backend + 2 frontend on different nodes, 1 postgres
kubectl -n argocd get application taskapp            # Synced, Healthy
curl -vI https://<your-domain>/                      # 200, valid Let's Encrypt cert
kubectl -n taskapp get hpa                            # backend-hpa present, TARGETS shows a real % not <unknown>
```

If any of those don't come back clean, `docs/RUNBOOK.md` §6 (Failure
recovery) is the place to look next.
