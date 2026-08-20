# Agentic SDLC Workshop

**The spec is the interface between humans and agents. Its precision is what
makes parallel work possible.**

A workshop for sales engineers on the evolution of agentic engineering and how
to apply it on GCP and the Gemini Enterprise Agent Platform. Half classroom,
half hands-on lab.

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

90 minutes, in Cloud Shell Editor. One link clones the repo, opens the editor,
and renders the lab steps in a side pane.

### The app

A **PR risk scorer**: reads a unified diff, reports a risk score, a tier, and
the named reasons behind it.

The feature you add is the scoring itself. It splits into two halves with a
seam the spec declares before anyone writes code:

| Half | Owner | Contract |
| --- | --- | --- |
| `diff.py` | Coder agent | `parse_diff(text) -> list[FileChange]` |
| `score.py` | You | `score(list[FileChange]) -> (score, tier, reasons)` |

`FileChange` is the seam. The spec fixes it, along with the exact scoring
weights and tier thresholds, so that two parties working independently arrive
at code that fits.

### The contract

Three tests, all emitted by the spec adversary and committed before either
party starts. A contract is testable from both sides independently — that is
what makes it a contract rather than a wish.

| Test | Run by | Asserts |
| --- | --- | --- |
| `test_parse_contract.py` | The agent, alone | `parse_diff(FIXTURE)` produces exactly this `list[FileChange]` |
| `test_score_contract.py` | You, alone | `score(<longhand FileChange list>)` produces exactly this tier and reasons |
| `test_integration.py` | Both, after merge | The two compose |

The longhand `FileChange` list in your test is the seam, written out by hand.

### The flow

1. **Draft the spec.** What the risk scorer should do.
2. **Harden it.** The spec adversary hunts for places two independent
   implementers could reasonably disagree, and makes you resolve each one.
3. **Take the contract.** The adversary emits the three tests. Commit them.
4. **Dispatch.** Push, then send the agent your repo and the **commit SHA**. It
   works against exactly that tree and cannot see anything you commit
   afterwards.
5. **Build in parallel.** You take `score.py`. The agent takes `diff.py`,
   streaming its full trajectory to your terminal and pushing a commit after
   every iteration.
6. **Integrate.** Merge `agent/diff` and run the integration test.
7. **Inspect the trajectory.** What it read, wrote, and retried — and what that
   tells you about trusting it.

Step 6 is the point of the workshop. It fits because the contract was precise,
not because anyone coordinated. Watching the agent work cannot change your half:
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
                "sha":"a1b2c3d","branch":"agent/diff"}}'
```

Nothing on the public internet can reach that resource, so there is no inbound
webhook.

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
gh repo deploy-key add agent_key.pub --allow-write --title "risk-scorer-agent"
```

Terraform writes it into Secret Manager and wires it to the agent. Blast radius
is one repository by construction.

## Skills

Two distribution mechanisms, because they are two different conversations:

- **`spec-adversary`** is installed from
  [`workshop-agentic-sdlc-skills`](https://github.com/OWNER/workshop-agentic-sdlc-skills),
  a repo students install from and never fork. That is the governance story: a
  platform team publishes a vetted standard.
- **`check-my-half`** the student writes themselves in about five minutes. That
  is the authoring story: ten lines of markdown, no approval, no release.

`docs/fallback/spec-adversary.md` is a complete copy parked outside the skill
discovery path. It never enters context, and it is one copy command away if the
plugin install fails.

## Setup

You need a GCP project with billing enabled and a GitHub account.

Run `./preflight.sh` **a week before the session**. It checks authentication,
billing, required APIs, org policy, quota, and `gh` login, and prints the exact
command to fix anything missing. Enabling APIs on the day costs 10–15 minutes
that the lab does not have.

```bash
gh auth login            # device code
gh repo fork --remote    # origin becomes your fork
```

## Open questions

- **`antigravity` is unverified.** The one dependency not yet installed and
  exercised. Three things to check first: its auth flow (a localhost redirect
  will not work in Cloud Shell, a device code will), whether it has a plugin
  model and what `install` accepts, and its memory footprint.
- **Timing.** The lab as specified is ~89 minutes of frictionless content in a
  90-minute slot.
- **Agent Runtime's maximum invocation duration.** If it is shorter than a
  red-to-green loop, dispatch changes from streaming to submit-and-poll.
- **Cloud Shell sizing** for the CLI. Cloud Workstations is the upgrade path.
- **How much Terraform students run** versus what preflight settles in advance.
