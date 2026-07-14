# Architecture

## Node topology

```
                         Internet
                            |
                     [ Network LB ]  <- AWS NLB, public subnets, SG: 80/443 only
                       80/443 TCP
                            |
              +-------------------------+
              |   k3s workers (x2+)     |  <- private subnets, 2 AZs
              |   ingress-nginx DaemonSet, NodePort 30080/30443
              +-------------------------+
                     |            |
              [frontend Pods] [backend Pods]  <- 2+ replicas each, spread
                                    |             across different nodes
                              [postgres-svc]
                                    |
                        [Postgres StatefulSet + PVC]
                          (pinned to one worker, via
                           the local-path storage class)

   Admin path (never touches app traffic):
   You -> bastion (public subnet, SSH from your IP only)
       -> SSH ProxyJump -> k3s-master-01 (private, port 6443 - never public)
       -> kubectl / Argo CD UI (port-forwarded through the same tunnel)
```

3 k3s nodes minimum (1 master + 2 workers) satisfies "real multi-node
scheduling" - `topologySpreadConstraints` on both Deployments then forces
the scheduler to actually use that spread rather than accidentally
co-locating both replicas of a tier on one node.

## Request flow: DNS → app

1. Your domain's DNS record (CNAME, or your registrar's ALIAS/flattened-
   CNAME for the apex) points at the **NLB's DNS name** (Terraform output
   `nlb_dns_name`).
2. The NLB forwards TCP 80/443 to whichever k3s workers are healthy, on
   the fixed NodePorts `30080`/`30443`.
3. **ingress-nginx** (running as a DaemonSet on every worker) terminates
   the connection, matches the `Host` header + path against the
   `Ingress` resource in `gitops/taskapp/60-ingress.yaml`, and either
   redirects HTTP→HTTPS or serves the request.
4. TLS itself is a **cert-manager**-issued Let's Encrypt certificate
   (`ClusterIssuer` from the `k3s_platform` Ansible role), auto-renewed,
   stored as the `taskapp-tls` Secret that cert-manager manages - not
   something Argo CD or Ansible touches again after the first issuance.
5. `/api/*` routes to the `backend` Service (→ backend Pods, port 5000);
   everything else routes to the `frontend` Service (→ frontend Pods,
   port 80). Same-origin, one certificate, no CORS to configure.
6. The backend talks to Postgres via the `postgres-svc` headless Service
   DNS name - resolves straight to the StatefulSet's Pod IP.

## Why the app is entirely GitOps-owned except one Secret

Argo CD (`argocd` namespace) watches `gitops/taskapp/` in this repo. Push
a change there → Argo CD notices within its poll interval (or
immediately, via a webhook if you wire one up) → reconciles the cluster
to match. `syncPolicy.automated` has `prune: true` and `selfHeal: true`,
so it also *reverts* anything applied outside of git - which is what
makes "GitOps owns the cluster" actually true rather than aspirational.

The one exception is the `taskapp-secrets` Secret (DB password /
connection string). It is applied by the `k3s_platform` Ansible role from
an ansible-vault-encrypted variable, **not** committed to
`gitops/taskapp/` in plaintext. Two ways to close this last gap properly,
not implemented here to keep the manifest set legible, but worth doing
next:
- **Sealed Secrets** (bitnami-labs/sealed-secrets): encrypt client-side
  with the cluster's public key, commit the ciphertext `SealedSecret` CR
  safely, a controller decrypts it into a real `Secret` in-cluster.
- **External Secrets Operator**: pull the value from AWS Secrets Manager
  at sync time instead of storing it anywhere in git, encrypted or not.

Either turns the Secret into a normal GitOps-owned resource. Until then,
it's the one deliberate, documented exception - the alternative (a
plaintext password in a public git repo) is a hard capstone violation and
not an acceptable trade to make for tidiness.

## For each Core requirement, the single-server assumption it fixes

| Core requirement | Single-server assumption it breaks |
|---|---|
| Namespace + ConfigMap/Secret split | On one box, "prod config" was just `.env` files on disk, readable by whoever could SSH in. Kubernetes makes the non-secret/secret boundary an actual API object with its own RBAC surface. |
| Postgres as StatefulSet + PVC | A single Postgres process on the app server assumed the disk under `/var/lib/postgresql` never moves. A Pod can be rescheduled at any time; the PVC is what makes "the database" outlive any one Pod (or even node, with network-attached storage - see the storage class trade-off below). |
| 2+ replicas, spread across nodes | One server meant one point of failure for the whole app tier. `topologySpreadConstraints` is what turns "2 replicas" from a number into an actual availability property - two replicas on the same node is still one point of failure. |
| Migrations as a Job, not the entrypoint | `alembic upgrade head` in the entrypoint is safe with exactly one process starting at a time. At 2+ replicas starting concurrently (a rolling update, a scale-up, a node coming back after a drain), N processes race on the same migration - the Job + Argo CD sync-wave ordering makes "run migrations" and "start serving traffic" two ordered steps again, the way they implicitly were on one box. |
| Liveness/readiness/startup probes | On one server, "is it up" was answered by SSHing in and checking a systemd unit or curling localhost. At N replicas across M nodes, nothing else knows if a given Pod is actually healthy - the probes are what let the platform answer that question itself, per-replica, continuously. |
| Resource requests/limits | A single EC2 instance's whole capacity was implicitly "the app's" resource budget. On a shared cluster, without requests/limits one workload can starve another, or the scheduler has no basis to decide where a Pod even fits. |
| `maxUnavailable: 0` rolling update | Deploying to one server meant *some* downtime was unavoidable during a restart. With 2+ replicas and this setting, the platform guarantees it never drops below full capacity during a deploy - something a single box structurally cannot do. |
| Ingress + real TLS | One server terminating TLS directly was one cert, one process, one config file. Ingress + cert-manager decouples "which service handles this path" from "where the cert lives" - and lets that path split (frontend vs backend) without either tier knowing about the other's existence. |
| Pinned image tags | `:latest` on one server meant "whatever I last pulled" - fine when there's one place to check. Across N replicas and M nodes, `:latest` means different Pods can silently be running different code with no record of which. |

## Known trade-offs / things to revisit

- **Storage class is `local-path`** (k3s's built-in default), which ties
  the Postgres Pod to whichever node its PVC was provisioned on - it
  reschedules back to that same node on a Pod delete (satisfies "data
  survives a Pod kill"), but can't float freely to a different node the
  way a network-attached volume could. For real portability across
  nodes, swap in the AWS EBS CSI driver + a `StorageClass` backed by
  `gp3` volumes. Not done here to keep the storage layer to what k3s
  ships out of the box; worth a follow-up given this is already running
  on AWS.
- **Frontend container's `runAsUser: 101`** assumes the nginx image can
  bind port 80 as a non-root user. Stock `nginx`/`nginx:alpine` images
  actually need root to bind ports <1024 (the master process starts as
  root, then drops privilege for workers) - if your frontend Dockerfile
  doesn't already handle this (e.g. `nginx-unprivileged` base image, or
  a config listening on a port ≥1024 behind the Service's port 80), this
  securityContext will crash-loop. Check your Dockerfile's base image
  before your first sync and adjust `runAsUser`/the listen port if
  needed.
