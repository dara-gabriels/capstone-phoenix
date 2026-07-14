# Cost

Estimates below use AWS on-demand list pricing (US East 1 as a baseline -
eu-north-1/Stockholm, the default region in this repo, typically runs
5-15% higher; check the [AWS Pricing Calculator](https://calculator.aws/)
for your exact region before relying on these numbers for a real budget).
730 hours/month.

| Item | Qty | Unit cost | Monthly |
|---|---|---|---|
| Bastion (`t3.micro`) | 1 | ~$0.0104/hr | ~$7.60 |
| k3s master (`t3.medium`) | 1 | ~$0.0416/hr | ~$30.37 |
| k3s workers (`t3.medium`) | 2 | ~$0.0416/hr | ~$60.74 |
| EBS `gp3` root volumes (30GB × 3 nodes + 20GB bastion + 5GB Postgres PVC) | ~135GB | ~$0.08/GB-mo | ~$10.80 |
| NAT Gateway (hourly) | 1 | ~$0.045/hr | ~$32.85 |
| NAT Gateway data processing | ~10GB/mo (light dev use) | ~$0.045/GB | ~$0.45 |
| Network Load Balancer (hourly) | 1 | ~$0.0225/hr | ~$16.43 |
| NLB LCU-hours (light traffic) | - | - | ~$5 |
| S3 (state bucket, versioned, tiny objects) | 1 | negligible | ~$0.10 |
| DynamoDB (lock table, on-demand) | 1 | negligible | ~$0.10 |
| Data transfer out (light dev traffic) | ~10GB | ~$0.09/GB | ~$0.90 |
| **Total (rough)** | | | **~$165/month** |

Notably **not** in this table because it's gone from the architecture:
the old standalone frontend/backend EC2 instances, and the RDS instance
that sat unused alongside the in-cluster Postgres - removing both of
those was itself a real cost cut, not just a tidiness fix.

## How to cut this roughly in half

The two biggest line items are the **NAT Gateway** (~$33/mo, mostly just
for the hourly charge regardless of how little data it moves) and the
**3× `t3.medium` nodes** (~$91/mo combined). Both are addressable without
giving up any Core requirement:

1. **Drop the NAT Gateway, use a NAT instance instead** (a `t3.nano` with
   `net.ipv4.ip_forward` + iptables MASQUERADE - what the old bastion role
   used to do, before this rewrite moved that job to the managed NAT
   Gateway for reliability). At dev/capstone traffic volumes a NAT
   instance is fine and costs ~$3-4/mo instead of ~$33/mo. Trade-off:
   you're back to a single point of failure and something to patch,
   which is exactly why production setups pay for the managed version -
   reasonable to accept for a capstone, not for a real prod workload.
2. **Downsize to `t3.small` for the two workers** (2 vCPU/2GiB instead of
   4GiB) if `kubectl top nodes` after a normal day shows headroom - the
   app itself (2 small Flask + nginx replicas) doesn't need 4GiB per
   node once you subtract what kube-prometheus-stack and the platform
   components reserve. Saves ~$30/mo across two nodes.

Together that's roughly $60-65/mo back, landing total spend closer to
$100-105/month - without touching HA, TLS, GitOps, or any of the Core
checklist.
