# Agentic SDLC Workshop

A workshop on building software with agents as teammates — half classroom, half
hands-on lab.

## Structure

| Part | Format | Duration |
| --- | --- | --- |
| Classroom | Presentation + discussion | TBD |
| Lab | Self-paced, guided | 90 minutes |

## The lab

The lab bootstraps a GCP environment, scaffolds an ADK agent, and puts that
agent to work alongside you on a real feature in a real repo.

**What you build**

An agent that participates in the inner development loop: it watches commits,
runs quality checks, and reports back as a teammate rather than a gate.

**What you use**

- **Terraform** — bootstraps the GCP environment
- **Gemini Enterprise Agent Platform** — hosts the agents
- **GitHub** — source and issues; you fork this repo so you can open issues against your own copy
- **agents-cli** — scaffolds the ADK agent
- **Antigravity CLI** — your interactive tool for parts of the lab

Not everything runs through the Antigravity CLI. Some steps are hand-driven on
purpose, so you see what the tooling is doing for you.

**How you work**

- **Spec-driven development** — an ordered process for instructing an agent and reviewing what it produces
- **TDD** — write the test, watch it fail, implement, watch it pass
- **Custom Antigravity CLI skills** — packaged workflows you invoke by name

## The agents

Two agents, working a handoff between them:

- **Coder** — writes code and tests
- **Adversarial reviewer** — opens a PR with feedback

The goal is a visible handoff: the reviewer's findings flow back into the
coder's next pass.

## Classroom topics

- **The evolution of AI-assisted development** — line of code → page of code → developer instructing an agent → agent teams
- **Spec-driven development** — the practice and the tools around it, including `grill-me`
- **The lab process** — walking the handoffs between agents
- **Evals and trajectories** — how they apply both during development and inside shipped agents
- **Agent memory vs. session** — what persists, what does not, and why it matters
- **Antigravity 2.0** — the SDK and the CLI

## Repo layout

TBD.
