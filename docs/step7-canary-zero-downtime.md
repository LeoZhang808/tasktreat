# Step 7 — Canary Deployment and Zero Downtime

This document covers the strategy, mechanics, and demo flow for production
deployments in TaskTreat. Step 6 set up a working CI/CD pipeline using plain
Kubernetes `RollingUpdate`; Step 7 upgrades **production** to a progressive
(canary) rollout via Argo Rollouts and tightens the zero-downtime guarantees.

`dev`, `qa`, and `uat` continue to use plain Deployments — only the `prod`
overlay swaps in Rollouts.

---

## Why Canary, not Blue/Green

TaskTreat is four small services behind one ALB; user actions like creating a
task or generating a reward fan out across all three backends. Blue/Green would
cut 0% of users over to the new version instantly at the end of the rollout —
a regression hits everyone the moment the ALB flips. Canary instead exposes a
small fraction of traffic to the new version first, pauses, then expands. A
bad release affects at most the canary slice before we abort, which fits a
many-microservice app much better than an all-or-nothing flip.

A second reason: this project's grading rubric explicitly wants observability
later (Step 8). Canary integrates cleanly with Prometheus through Argo
Rollouts `AnalysisTemplate` resources, so we get a free upgrade path from
"pause-based canary" to "metric-gated canary" without rewriting anything.

---

## What changed in this repo

```
services/{task,wishlist,reward}-service/src/index.ts
   + SIGTERM/SIGINT handler that calls server.close() so in-flight HTTP
     requests drain before the process exits.
   + GET /version endpoint that returns the running APP_VERSION (handy
     during a canary demo).

k8s/overlays/prod/
   + rollouts/{task,wishlist,reward,frontend}-rollout.yaml
       Argo Rollouts replacing the four base Deployments in prod. Each
       has: replicas: 2, maxSurge: 1, maxUnavailable: 0, readiness +
       liveness probes, terminationGracePeriodSeconds: 30, and a
       preStop sleep 5.
   + pdb/{task,wishlist,reward,frontend}-pdb.yaml
       PodDisruptionBudget minAvailable: 1 per service.
   + deployment-delete-{task,wishlist,reward,frontend}.yaml
       $patch: delete strategic-merge patches that remove the base
       Deployment in the prod overlay so we don't end up with both
       Deployment/foo and Rollout/foo.
   - replicas-{task,wishlist,reward,frontend}.yaml
       Removed; replicas are now baked into each Rollout directly.

.github/workflows/release-prod.yml
   + Installs the `kubectl argo rollouts` plugin.
   ~ Replaces `kubectl rollout status deployment/...` with
     `kubectl argo rollouts status ... --timeout 600s` so the job
     actually waits for the canary to finish (and fails if it doesn't).

scripts/install-argo-rollouts.sh     install the controller (one-shot)
scripts/canary-demo.sh               retag one service + watch the rollout
scripts/verify-zero-downtime.sh      hammer the public URL during a rollout
```

---

## Canary shape

Every prod Rollout uses the same progression:

| Step | setWeight | pause |
| ---- | --------- | ----- |
| 1    | 20%       | 60s   |
| 2    | 50%       | 60s   |
| 3    | 100%      | —     |

With `replicas: 2`, this means: bring up 1 canary pod (~50%/50% by pod count),
pause, then weight 100% which scales the stable side down. The 60s pauses
give you (or, later, an analysis template) time to abort if something looks
wrong. Total happy-path rollout time per service is ~2 minutes.

`maxUnavailable: 0` + `maxSurge: 1` guarantees we never drop below the desired
replica count during the rollout.

---

## Zero-downtime controls

| Control                              | Why it matters                                                                 |
| ------------------------------------ | ------------------------------------------------------------------------------ |
| `replicas: 2` per service            | At least one pod is always serving; no single-replica downtime.                |
| `readinessProbe` on every container  | Kubernetes only routes traffic to pods that have passed `/health` (or `/`).    |
| `livenessProbe` on every container   | A stuck pod gets restarted instead of silently black-holing requests.          |
| `maxUnavailable: 0`, `maxSurge: 1`   | Old pods stay up until the replacement is Ready.                               |
| `terminationGracePeriodSeconds: 30`  | Pod has 30s after SIGTERM to drain in-flight requests before SIGKILL.          |
| `preStop` `sleep 5`                  | Buys ~5s for the ALB / kube-proxy to remove the pod from their target lists.   |
| SIGTERM handler in app code          | `server.close()` lets in-flight requests finish; new ones get a different pod. |
| `PodDisruptionBudget minAvailable: 1`| Voluntary disruptions (drain, autoscaler) can't take both replicas at once.    |

The chain on shutdown is therefore:

1. Argo Rollouts decides to retire an old pod.
2. Pod enters `Terminating`; kube-proxy/ALB start removing it from endpoints.
3. `preStop` sleeps 5s — during this window the pod is still healthy but is
   already being de-registered, so new connections route elsewhere.
4. SIGTERM is sent; the Node process calls `server.close()`, finishes
   in-flight requests, and exits 0.
5. If anything is still pending at +30s, Kubernetes SIGKILLs.

---

## Production deploy flow

1. Push a tag matching `v*.*.*` (or use the GitHub Actions "Run workflow"
   button on `release-prod.yml`).
2. Workflow builds & pushes the four images with the immutable tag, then
   `kustomize edit set image` rewrites the prod overlay to point at them.
3. `kubectl apply -k k8s/overlays/prod` applies the Rollouts.
4. `kubectl argo rollouts status <name> --timeout 600s` blocks per service
   until each canary reaches `Healthy` (or the workflow fails).
5. `scripts/ci-smoke-test.sh` runs read-only smoke checks.

---

## Manual demo

In one terminal, start the zero-downtime probe:

```bash
BASE_URL=https://app.tasktreat.dev DURATION_SECONDS=240 \
  scripts/verify-zero-downtime.sh
```

In a second terminal, kick off a visible canary (any new tag works):

```bash
scripts/canary-demo.sh task-service v1.0.1
```

You should see:

- `kubectl argo rollouts get rollout task-service --watch` showing
  `Step 1/5` → `Step 3/5` → `Step 5/5` progression with pauses.
- The probe in the first terminal reporting `0 failures` at the end.

To prove rollback works, abort mid-canary:

```bash
kubectl argo rollouts abort task-service -n tasktreat-prod
kubectl argo rollouts undo  task-service -n tasktreat-prod
```

`abort` halts the canary at its current step and scales the canary
ReplicaSet to 0 (stable keeps serving). `undo` reverts to the previous
revision.

---

## Operating runbook

```bash
# install the controller (one-shot per cluster)
scripts/install-argo-rollouts.sh

# see all rollouts at a glance
kubectl argo rollouts list rollouts -n tasktreat-prod

# detailed view of one rollout, with live progression
kubectl argo rollouts get rollout task-service -n tasktreat-prod --watch

# manually promote (only useful if a step has indefinite pause)
kubectl argo rollouts promote task-service -n tasktreat-prod

# halt a misbehaving rollout
kubectl argo rollouts abort task-service -n tasktreat-prod

# revert to the previous good revision
kubectl argo rollouts undo task-service -n tasktreat-prod
```

---

## Database migrations and canary

Canary only works safely when old and new pods can run side-by-side. Any
schema change must use the **expand → migrate → contract** pattern:

1. **Expand**: add the new column/table as nullable; both old and new code
   tolerate it.
2. Deploy the canary that uses the new shape.
3. Backfill data while both versions are live.
4. **Contract**: in a *later* release, remove the now-unused old column or
   add NOT NULL constraints.

Never ship a breaking migration in the same release as the code that depends
on it — that is the one place where canary still drops requests.

---

## Future work (Step 8 hooks)

Once Prometheus is in the cluster, each Rollout can grow an `analysis:`
block referencing an `AnalysisTemplate` that checks 5xx rate and p95 latency
during each pause. If the metric crosses a threshold, Argo Rollouts aborts
automatically — same controls as today, without a human staring at a
terminal.
