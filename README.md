# Agentic SDLC Workshop

**The spec is the interface between humans and agents. Its precision is what
makes parallel work possible.**

A 90-minute customer session on the evolution of agentic engineering and how to
apply it on GCP and the Gemini Enterprise Agent Platform. Delivered by a sales
engineer to a customer's developers. Half classroom, half hands-on lab.

Attendees work in **their own GCP projects and their own GitHub accounts**. The
point is that it worked here, in their org, under their policies.

Most agent demos are serial: you ask, the agent answers, you review. This
workshop is about the next step — a developer and an agent building two halves
of one feature **at the same time**, meeting at a seam that neither of them
negotiated at runtime, because the spec declared it in advance.

## Classroom

Each step in the evolution of agentic engineering creates a need, and a
platform capability answers it. The product tour and the narrative are the same
thing.

| Evolution step | The need it creates | What answers it |
| --- | --- | --- |
| Line of code → page of code | — | Models |
| A developer instructing an agent | A repeatable way to define one | ADK, `agents-cli` |
| Agents that outlive your terminal | Somewhere to run, an identity | Agent Platform, Sessions |
| Agents that remember across runs | State beyond one conversation | Memory Bank |
| Agents you are willing to trust | Evidence of how they behave | Evals, trajectories |
| Agents working *beside* you | A contract to coordinate on | The lab |

Antigravity 2.0, the SDK, and the CLI appear where they answer a need, not as a
standalone tour.

## Lab

90 minutes, in Cloud Shell Editor. One link forks `workshop-agentic-sdlc-lab`,
opens the editor on it, and renders `tutorial.md` in a side pane.

### The app

An **account health scorer**: reads a usage export, reports a health score, a
tier, and the named reasons behind it.

```
ACME Corp: AT RISK
  seats down 40% over 3 months
  no logins in 14 days
  2 open P1 tickets
```

It starts from a request, not a spec:

> **Flag accounts before they churn**
>
> CS finds out an account is unhappy when the cancellation email arrives. We
> want a health signal per account so they can reach out first. Raised at two
> QBRs now.

That is unbuildable as written, and deliberately so. What counts as risk, what
window matters, how many tiers there are, where the boundaries sit — none of it
is stated, and all of it has to be decided before two parties can work in
parallel.

### The seam

| Half | Owner | Contract |
| --- | --- | --- |
| `usage.py` | Coder agent | `parse_usage(csv) -> list[MonthSnapshot]` |
| `score.py` | You | `score(list[MonthSnapshot]) -> (score, tier, reasons)` |

`MonthSnapshot` is the seam. The spec fixes it, along with the exact weights
and tier thresholds, so that two parties working independently arrive at code
that fits.

### The contract

Three tests, emitted by the spec adversary and committed before either party
starts. A contract is testable from both sides independently — that is what
makes it a contract rather than a wish.

| Test | Run by | Asserts |
| --- | --- | --- |
| `test_parse_contract.py` | The agent, alone | `parse_usage(FIXTURE)` produces exactly this `list[MonthSnapshot]` |
| `test_score_contract.py` | You, alone | `score(<longhand MonthSnapshot list>)` produces exactly this tier and reasons |
| `test_integration.py` | Both, after merge | The two compose |

The longhand `MonthSnapshot` list in your test is the seam, written out by hand.

### The flow

1. **File the request.** `gh issue create -F docs/request.md`. Work starts where
   work starts.
2. **Read the draft spec.** It ships in the lab repo and reads as a competent
   first pass. It is not.
3. **Harden it.** The spec adversary hunts for places two independent
   implementers could reasonably disagree, and makes you resolve each one. The
   adversary finds them; you decide them. Deciding is the transferable skill.
4. **Take the contract.** The adversary emits the three tests. Commit them.
5. **Dispatch.** Push, then send the agent your repo and the **commit SHA**. It
   works against exactly that tree and cannot see anything you commit
   afterwards.
6. **Build in parallel.** You take `score.py`. The agent takes `usage.py`,
   streaming its full trajectory to your terminal and pushing a commit after
   every iteration.
7. **Integrate.** Merge `agent/parse` and run the integration test.
8. **Inspect the trajectory.** What it read, wrote, and retried — and what that
   tells you about trusting it.
9. **Eval the adversary.** The draft spec is a golden case: you know what a good
   adversary finds in it, because you just resolved it by hand. One case, one
   command, and an answer to "how would you know if this agent got worse?"

Step 7 is the point of the workshop. It fits because the contract was precise,
not because anyone coordinated. Students who resolve an ambiguity differently
still succeed: the adversary encodes *their* decision into *their* contract, and
the agent codes against that. The lab does not require the right answer. It
requires an answer, written down before work starts. Watching the agent work cannot change your half:
your target is `test_score_contract.py`, and it does not move.

## Architecture

Where a thing runs follows from what it does.

| Party | Runs | Why there |
| --- | --- | --- |
| Spec adversary | Local, Antigravity CLI skill | Interactive, high-iteration, ephemeral. A round trip per turn would ruin it |
| You | Local | — |
| Coder agent | Agent Platform | It works *at the same time as you*. Parallelism needs a separate execution context |

The coder agent is an ADK agent, scaffolded with `agents-cli`, wrapping the
Antigravity SDK. Agent Platform is where an agent lives; the SDK is what an
agent can do.

### Dispatch

The agent is a Google API resource, not a public endpoint. The call is
authorized by ADC — in Cloud Shell, the student's own identity — and held open
for the duration so the trajectory streams back:

```bash
ENGINE="projects/$PROJECT/locations/$REGION/reasoningEngines/$ENGINE_ID"

curl -X POST "https://$REGION-aiplatform.googleapis.com/v1/$ENGINE:streamQuery" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -d '{"class_method":"dispatch",
       "input":{"repo":"git@github.com:you/fork.git",
                "sha":"a1b2c3d","branch":"agent/parse"}}'
```

Nothing on the public internet can reach that resource, so there is no inbound
webhook.

### Region

"Location" is three values, and they are not interchangeable.

| Value | Names | The lab pins |
| --- | --- | --- |
| Model location | Which endpoint serves the model | `MODEL_LOCATION`, often `global` |
| Engine location | Where the engine runs, and where Sessions live | `AGENT_ENGINE_LOCATION`, a real region |
| Deploy region | Where the deploy lands | `AGENT_ENGINE_LOCATION` |

`global` is a model endpoint, not a region. Some model versions are served only
from it and a regional endpoint returns **404** for them, which reads as a bad
model name rather than a bad location. Interpolated into a regional host it
yields `global-aiplatform.googleapis.com`, which does not resolve.

**Neither variable has a default.** A guessed region builds a URL that resolves
and points somewhere else — the agent is reachable and its sessions come back
empty, with nothing indicating why. Preflight refuses to continue if either is
unset.

### Agent runtime

The working copy is ephemeral. `/tmp` is tmpfs and counts against memory, so
pytest and the app's dependencies are baked into the container image and the
clone is shallow. **The durable state is the branch, not the filesystem** — a
third category beside Sessions and Memory Bank: externalised artifacts.

Start at 2 GB and measure; 1–2 vCPU is ample, since the loop is model-latency
bound. The agent iterates until the contract test passes, bounded by a deadline
derived from the invocation timeout rather than an attempt count — it pushes
what it has when the clock runs out.

### Push credentials

The agent pushes with a **deploy key** — an SSH key scoped to one repository,
created with the `gh` credentials the student already has:

```bash
ssh-keygen -t ed25519 -f agent_key -N ""
gh repo deploy-key add agent_key.pub --allow-write --title "health-scorer-agent"
```

The key goes into Secret Manager and is wired to the agent. Blast radius is one
repository by construction.

## Skills

Two distribution mechanisms, because they are two different conversations:

- **`spec-adversary`** is installed from this repo, which students install from
  and never fork. That is the governance story: a platform team publishes a
  vetted standard.
- **`check-my-half`** the student writes themselves in about five minutes. That
  is the authoring story: ten lines of markdown, no approval, no release.

The skill source lives here in `skills/`. If the plugin install fails, the file
is already on disk in a repo they cloned a week ago — one copy command, and
nothing sat in the lab repo's discovery path in the meantime.

## Repos

One rule decides which repo a thing belongs in: **do students fork it?**

| Repo | Students | Contents |
| --- | --- | --- |
| `workshop-agentic-sdlc` | Clone and install from. Never fork | This README, classroom outline, `preflight.sh`, `terraform/`, `skills/` |
| `workshop-agentic-sdlc-lab` | Fork on the day | The app, `docs/spec.md`, `docs/request.md`, `tutorial.md` |

The lab repo opens at kickoff. The rubric and the walkthrough are where the
lab's discoveries live, and a student who read them last week does not get to
make them.

## Before the session

Attendees need a GCP project with billing enabled and a GitHub account.

Clone this repo and run `./preflight.sh` **before the session**. It:

- checks authentication, billing, required APIs, org policy, quota, and `gh` login
- prints the exact command to fix anything missing
- installs the `spec-adversary` plugin and verifies it loads
- validates `AGENT_ENGINE_LOCATION` and `MODEL_LOCATION` against quota, model
  availability, and org policy
- creates the `aiplatform` service identity, then runs `terraform apply` for the
  static infrastructure: service account, IAM, and an empty Secret Manager secret

Service agents are created lazily — they do not exist until their API is first
used, so `gcloud beta services identity create` must run before Terraform binds
anything, or grants fail with `INVALID_ARGUMENT: ... does not exist`. The
runtime principal is `gcp-sa-aiplatform-re`, which is not the same as
`gcp-sa-aiplatform`. Never mask a grant with `|| true`: a masked failure
resurfaces as an unexplainable 403 during deployment.

The split is by what a step touches. **Anything touching only your GCP project
runs a week early. Anything touching your fork must wait**, because the fork
does not exist yet. Day-of steps address resources by deterministic name rather
than Terraform outputs, so it does not matter where or when preflight ran.

Both of the lab's day-of blockers retire here: enabling APIs costs 10–15
minutes the lab does not have, and a failed plugin install sits directly
upstream of the tool that produces the contract.

`preflight.sh` is re-runnable and reports nothing anywhere. Its output is for
the attendee, and a nudge from the session sponsor is what moves completion.

## On the day

```bash
gh auth login                                                  # device code
gh repo fork OWNER/workshop-agentic-sdlc-lab --clone --remote
```

Then `agents-cli` scaffolds the agent, you deploy it, and the deploy key is
created and written into the secret.

## Pacing

The lab has one hard gate: **dispatch**. The agent needs wall-clock time to
work, so an attendee who has not dispatched by the stated minute cannot reach
step 7 at all. Everything else can slip.

The lab repo carries checkpoint branches for anyone behind:

```bash
git merge upstream/checkpoint/4-contract-committed
```

Fast finishers run the eval, then hunt a second seeded ambiguity.

## Open questions

- **`antigravity` is unverified.** The one dependency not yet installed and
  exercised. Three things to check first: its auth flow (a localhost redirect
  will not work in Cloud Shell, a device code will), whether it has a plugin
  model and what `install` accepts, and its memory footprint.
- **Timing.** The lab as specified is ~89 minutes of frictionless content in a
  90-minute slot that a customer has committed to. There is no slack, and the
  customer has a next meeting.
- **Reachability.** The fork, the deploy key, and the agent's push all assume
  `github.com`. An enterprise network that blocks it takes the lab to zero.
- **Agent Runtime's maximum invocation duration.** If it is shorter than a
  red-to-green loop, dispatch changes from streaming to submit-and-poll.
- **Cloud Shell sizing** for the CLI. Cloud Workstations is the upgrade path.
