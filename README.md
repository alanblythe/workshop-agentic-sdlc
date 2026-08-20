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

### The flow

1. **Draft the spec.** What the risk scorer should do.
2. **Harden it.** The spec adversary — a local Antigravity CLI skill — hunts
   for places two independent implementers could reasonably disagree, and makes
   you resolve each one.
3. **Take the contract.** The adversary emits an executable contract test. You
   commit it before either party starts.
4. **Split and go.** You take `score.py`. The coder agent takes `diff.py` and
   works concurrently, pushing commits to its own branch on your fork.
5. **No peeking.** Its commits arrive while you work. You do not read them
   until your own tests are green.
6. **Integrate.** Merge the agent's branch and run the contract test.
7. **Inspect the trajectory.** What the agent read, wrote, and retried, and
   what that tells you about trusting it.

Step 6 is the point of the workshop. It fits because the contract was precise,
not because anyone coordinated.

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

It pushes to your fork using a **deploy key** — an SSH key scoped to one
repository, created by script with the `gh` credentials you already have:

```bash
ssh-keygen -t ed25519 -f agent_key -N ""
gh repo deploy-key add agent_key.pub --allow-write --title "risk-scorer-agent"
```

Terraform writes the key into Secret Manager and wires it to the agent. Blast
radius is one repository by construction.

## Setup

You need a GCP project with billing enabled and a GitHub account. Everything
else the lab installs or provisions.

```bash
gh auth login            # device code
gh repo fork --remote    # origin becomes your fork
```

## Open questions

- **`antigravity` is unverified.** It is the one dependency in the stack not yet
  installed and exercised. Its auth flow matters most: a localhost redirect will
  not work in Cloud Shell, a device code will.
- **Timing.** The lab as specified is ~89 minutes of frictionless content in a
  90-minute slot. It needs simplification, or a longer slot.
- **Cloud Shell sizing.** Whether its machine is large enough to run the
  Antigravity CLI comfortably. Cloud Workstations is the upgrade path.
- **How the coder agent is dispatched** and receives the spec and contract test.
- **Which custom CLI skills to ship** beyond the spec adversary.
- **How much Terraform students run themselves** versus what is pre-provisioned.
