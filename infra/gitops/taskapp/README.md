# gitops/taskapp — this is what Argo CD watches

Everything in this directory is applied by Argo CD, automatically, on every
push to `main` (see `syncPolicy.automated` in the root `Application` -
`ansible/roles/k3s_platform/templates/root-application.yaml.j2`). Nobody
runs `kubectl apply` against these resources by hand once the cluster is
bootstrapped.

**Before your first push**, replace `taskapp.example.com` in
`60-ingress.yaml` with your real domain (two places: `tls.hosts` and
`rules.host`). This file is plain YAML, not templated - Argo CD doesn't
run Jinja, so this one edit has to be a real commit.

## Ordering (`argocd.argoproj.io/sync-wave`)

Argo CD applies lower wave numbers first and waits for each wave to be
healthy before moving to the next:

| Wave | Resources | Waits for |
|---|---|---|
| -3 | Namespace, ConfigMap | exists |
| -2 | Postgres StatefulSet + PVC + Service | Pod Ready |
| -1 | DB migration Job | Job `Complete` |
| 0 | Backend + frontend Deployments + Services | Deployment `Available` |
| 1 | HPA, PDBs, NetworkPolicy, Ingress | exists |

This is what makes the migration-race requirement in the capstone brief
hold: migrations always finish *before* any backend replica starts
serving traffic, on every sync - not just the first one.

## What's deliberately NOT here

`taskapp-secrets` (the Postgres password / connection string) is applied
out-of-band by Ansible from an ansible-vault-encrypted variable, not by
Argo CD. See `docs/ARCHITECTURE.md` for why. If you rotate the password,
re-run `ansible-playbook playbooks/deploy_gitops.yaml` - Argo CD's
`selfHeal` won't touch a resource it doesn't own.
