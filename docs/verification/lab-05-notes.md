# LAB-05 — Terraform, and the `-re` ordering decision

`terraform/` creates the agent's service account and its IAM, and an empty
Secret Manager secret for the deploy key. It is invoked by `preflight.sh`, in
the attendee's own project, up to a week before the session.

## Resource names are fixed strings

Day-of steps run in a different clone of a different repo and cannot read this
state. Both names are constants in `terraform/locals.tf`, not variables:

| Resource | Name |
|---|---|
| Agent service account | `agentic-sdlc-coder@PROJECT_ID.iam.gserviceaccount.com` |
| Deploy key secret | `agentic-sdlc-deploy-key` |

The outputs exist for preflight to echo back. Nothing on the day may consume
them.

## The decision: keep `-re` off the agent's permission path

`gcp-sa-aiplatform-re` is created by the project's **first Agent Runtime deploy
of running code**. Nothing else mints it — `gcloud beta services identity
create --service=aiplatform.googleapis.com` mints `gcp-sa-aiplatform`, a
different principal, and `reasoningengine.googleapis.com` and
`aiplatform-re.googleapis.com` are not service names that resolve. A sourceless
create with `identityType: AGENT_IDENTITY` returns an engine in ~20s and yields
an Agent Identity, but does not mint `-re` either. So on a fresh project, at
preflight time, the principal does not exist and any binding naming it is
refused with `INVALID_ARGUMENT: ... does not exist`.

The choice made is **(c): scope the design so the agent's own permissions never
name `-re`**, with the irreducible remainder handled as an explicit **(a)**
second stage.

**The engine runs as a custom service account.** Deploy with
`agents-cli deploy --service-account agentic-sdlc-coder@PROJECT.iam.gserviceaccount.com`.
That is what makes (c) work, and it is a requirement on lab step 3, not a
preference. Left off, the engine runs as `gcp-sa-aiplatform-re` — `agents-cli`
prints exactly that after a deploy — and then the *agent's* Secret Manager
grant would have to name `-re`, which is precisely the binding preflight cannot
make. With the custom service account, every grant the running agent depends on
lands on a principal Terraform created moments earlier:

- `roles/secretmanager.secretAccessor` on the secret, not project-wide
- `aiplatform.user`, `serviceusage.serviceUsageConsumer`, `logging.logWriter`,
  `monitoring.metricWriter`, `cloudtrace.agent` at project level

Options (b) and the do-nothing variants were rejected:

- **(b) mint the principal early** — no mechanism does it. The one that looks
  like it should (`services identity create`) mints the wrong agent, and the
  sourceless-with-Agent-Identity create was tested today and did not mint it.
- **Run as `-re` and grant the secret on the day** — this is the live fallback
  if the residual grant below proves unworkable. It costs preflight its service
  account entirely and moves one IAM command into lab step 7, after the deploy
  has minted the principal. It is lower risk on the day and lower least
  privilege: `-re` already carries `roles/aiplatform.serviceAgent` project-wide.

## The residual grant, and why it is gated rather than masked

A custom service account on Agent Runtime requires **one** binding to `-re`:
`roles/iam.serviceAccountTokenCreator`, on the service account, so the platform
can impersonate it. This is documented, not inferred
([custom service account](https://docs.cloud.google.com/gemini-enterprise-agent-platform/machine-learning/general/custom-service-account)).
It is a resource-level binding on a service account Terraform owns, so it is
one line — but the principal still has to exist.

`terraform/service_account.tf` therefore takes a required variable
`runtime_service_agent_exists` with **no default**. Terraform will not guess:

- `true` — the binding is created.
- `false` — the binding is not planned, and
  `runtime_service_agent_impersonation_granted` reports `false` so preflight can
  say what was deferred and why.

This is a second stage, not a masked failure. Nothing swallows an error; the
caller states a fact it checked with a read-only probe, and re-applying after
the first deploy converges. The probe:

```bash
gcloud iam service-accounts describe \
  "service-$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')@gcp-sa-aiplatform-re.iam.gserviceaccount.com"
```

## The open risk — this is what the rehearsal must settle

**On a project that has never deployed an engine, the first deploy is the thing
that creates `-re`, and it is also the thing that needs `-re` to already hold
`serviceAccountTokenCreator`.** Whether that first custom-service-account deploy
succeeds, fails and succeeds on retry, or fails outright, is **unmeasured**. It
cannot be measured in `ws1` (already warmed) and must not be measured in `ws2`
outside a rehearsal run.

The experiment that would retire the risk, untested and not run here because it
writes:

```bash
gcloud workload-identity service-agents generate \
  --service="aiplatform.googleapis.com" --location="global" --project=PROJECT_NUMBER
```

IAM documents this as creating **all** service agents for a service at a
resource — a different API (`workloadidentity.googleapis.com`) from the
`services identity create` path that was tested and found wanting. If it mints
`-re`, preflight can call it, pass `runtime_service_agent_exists=true`, and the
whole ordering problem disappears into one line. If it does not, take the
`-re`-as-runtime-identity fallback above and drop the custom service account.

Run it against a scratch project — not `ws2`.

## Consequences for other issues

- **LAB-04 (`preflight.sh`)** — the `gcloud beta services identity create` step
  in the README's preflight description grants nothing under this design and
  can go. Preflight instead probes for `-re` and passes the result in. The
  Terraform owns the canonical API list (`terraform/locals.tf`); preflight's API
  check is a courtesy that produces a better error, not a second owner.
- **LAB-12 / LAB-15 (step 3)** — the deploy command must carry
  `--service-account`. Without it the lab breaks at dispatch, with a 403 reading
  the secret.
- **LAB-19 (teardown)** — `terraform destroy` removes the service account, its
  bindings and the secret. APIs stay enabled (`disable_on_destroy = false`): an
  attendee's project may have been using them before the workshop.

## Deliberately not built

- **No `roles/iam.serviceAccountUser` for the deploying human.** Owner and
  Editor both carry `iam.serviceAccounts.actAs`, and reading the caller's
  identity needs an ADC scope Terraform is not guaranteed to have. If a
  restricted attendee hits `PERMISSION_DENIED ... actAs`:
  ```bash
  gcloud iam service-accounts add-iam-policy-binding \
    "agentic-sdlc-coder@$PROJECT.iam.gserviceaccount.com" \
    --member="user:$(gcloud config get-value account)" \
    --role=roles/iam.serviceAccountUser
  ```
- **No engine.** Creating one at preflight would put a billed resource in the
  attendee's project a week early, and its identity is not what the design
  binds against.

## Validation performed

`terraform fmt`, `terraform init -backend=false`, `terraform validate` — clean.
No `apply`, and no project touched. The three refusals were exercised with a
plan against a nonexistent project and an invalid token:

| Input | Result |
|---|---|
| No variables set | `No value for required variable` ×4 |
| `agent_engine_location=global` | Rejected: `global` is a model endpoint, not a region |
| `model_location == agent_engine_location` | Precondition failed: the two are independent |

`.terraform.lock.hcl` is locked for `linux_amd64`, `linux_arm64`,
`darwin_amd64` and `darwin_arm64`, because preflight runs in Cloud Shell for
some attendees and on a laptop for others.
