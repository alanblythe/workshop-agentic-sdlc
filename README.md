# Agentic SDLC Workshop

**The spec is the interface between humans and agents. Its precision is what
makes parallel work possible.**

A three-hour customer session on the evolution of agentic engineering and how
to apply it on GCP and the Gemini Enterprise Agent Platform. Delivered by a
customer engineer to a customer's developers: 90 minutes classroom, 90 minutes
hands-on lab.

Attendees work in **their own GCP projects and their own GitHub accounts**. The
point is that it worked here, in their org, under their policies.

Most agent demos are serial: you ask, the agent answers, you review. This
workshop is about the next step, a developer and an agent building two halves
of one feature, meeting at a seam that neither of them negotiated at runtime,
because the spec declared it in advance. The developer's half is the contract,
the resolved spec and the acceptance tests a subagent writes from it. The
agent's half is the implementation that has to pass them.

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

90 minutes. The guide is a codelab; the work happens in Cloud Shell Editor,
launched from an **Open in Cloud Shell** button inside it.

`lab.lab.md` is authored in DevSite CLaaT format and rendered with `claat
export` to GitHub Pages, so it looks like any other Google codelab, step
drawer, progress bar, `Duration:` tags summed in the navbar. Publishing it to
`codelabs.developers.google.com` later is moving one file.

The `Duration:` tags are not decoration. They are what holds the 90 minutes
together, and the sum is visible to the attendee throughout.

### The app

An **account health scorer**: reads a usage export, reports a health score, a
tier, and the named reasons behind it.

```
ACME Corp: AT RISK
  seats down 40% over 3 months
  no logins in 14 days
  2 open P1 tickets
```

The starter tree is `scorer/main.py`, `scorer/tests/`, and the export in
`fixtures/usage.csv`. It starts from a request, not a spec:

> **Flag accounts before they churn**
>
> CS finds out an account is unhappy when the cancellation email arrives. We
> want a health signal per account so they can reach out first. Raised at two
> QBRs now.

That is unbuildable as written, and deliberately so. What counts as risk, what
window matters, how many tiers there are, where the boundaries sit, none of it
is stated, and all of it has to be decided before two parties can work in
parallel.

### The seam

| Half | Written by | Artifact |
| --- | --- | --- |
| What "done" means | `contract-writer`, steered by you | `scorer/tests/`, and the stubs it calls in `scorer/usage.py` |
| Code that means it | The deployed agent, unsupervised | `scorer/usage.py` |

Nobody hand-writes Python. Both halves are agent-written; what differs is
whether anyone is watching.

`MonthSnapshot` is the seam inside the spec: `parse_usage` produces them and
`score` consumes them, so each side is testable without the other's code. The
spec fixes it, along with the exact weights and tier thresholds, so the
assertions can be written before the implementation exists.

### The contract

Three tests, emitted by the `contract-writer` subagent the adversary hands off
to, and committed before the agent starts. A contract is testable from both
sides independently, that is what makes it a contract rather than a wish.

| Test | Verifies | Asserts |
| --- | --- | --- |
| `test_parse_contract.py` | Parsing, alone | `parse_usage(FIXTURE)` produces exactly these snapshots |
| `test_score_contract.py` | Scoring, alone | `score(<longhand MonthSnapshot list>)` produces exactly this tier and reasons |
| `test_integration.py` | The two composed | Parse then score, end to end |

The longhand `MonthSnapshot` list in your test is the seam, written out by hand.

### The steps

`Duration:` tags sum into the codelab's navbar, so the budget is visible to the
attendee throughout.

| # | Step | Duration |
| --- | --- | --- |
| 1 | Before you begin | 0:02 |
| 2 | Fork the lab repository | 0:03 |
| 3 | Restore your Cloud Shell | 0:02 |
| 4 | Deploy the coder-agent | 0:04 |
| 5 | Read the request, then the spec | 0:06 |
| 6 | **Interrogate the spec** | 0:12 |
| 7 | Emit the contract | 0:08 |
| 8 | Check the deploy landed | 0:03 |
| 9 | Ensure git config is correct | 0:01 |
| 10 | Give the agent a GitHub deploy key to your fork | 0:04 |
| 11 | Dispatch coder-agent | 0:05 |
| 12 | Read what it did | 0:06 |
| 13 | Tear it down | 0:04 |
| | **Total** | **60 min** |

Sixty minutes of content in the ninety-minute half. The slack is deliberate:
this runs in a customer's environment, which nobody has tested. The table is
generated from the guide source into `agentic-sdlc-presenter/content-outline.md`
on every publish; that copy is the one that cannot drift.

**Step 4 starts the deploy and walks away.** `--no-wait` returns as soon as the
build is submitted, so it runs while steps 5–7 happen, and step 8 verifies it
before dispatching. Waiting for a deploy teaches nothing.

**Step 6 is the lab**, twelve of the sixty minutes. The adversary surfaces one
ambiguity at a time and shows both readings and how they diverge, *empty
`seats_active`: zero, so the account collapsed, or unknown, so skip the month?*
You choose. It writes your choice into the spec and moves on. It finds them;
**you** decide them.

**Step 11 is what they came to see.** The agent works from the contract alone,
on Agent Platform, narrating every file it reads and every command it runs.
Watch which files it edits: only `scorer/usage.py` is inside the contract, and
an edit naming a test is the agent changing what "done" means.

**Step 12 is the point.** It fits because the contract was precise, not because
anyone coordinated. Attendees who resolved an ambiguity differently still
succeed, the adversary encoded *their* decision into *their* contract, and the
agent coded against it. The lab does not require the right answer. It requires
an answer, written down before work starts.

Then the debrief line: *twenty minutes deciding what done means, five minutes
dispatching, and it fit first time. Which half did you expect to be the work?*

## Architecture

Where a thing runs follows from what it does.

| Party | Runs | Why there |
| --- | --- | --- |
| Spec adversary | Local, Antigravity CLI skill | Interactive, high-iteration, ephemeral. A round trip per turn would ruin it |
| `contract-writer` | Local, Antigravity CLI subagent | Supervised. You approve each turn, so **you** are the contract |
| Deployed coder | Agent Platform | Unsupervised, holding to a contract you are not there to enforce. **The test** is the contract |

That contrast is the lab's argument: you can only let an agent work
unsupervised if something other than you is holding it to the spec.

The coder agent is an ADK agent wrapping the Antigravity SDK. It ships built
in the lab repo and attendees deploy it with `agents-cli deploy`; nobody
scaffolds one during the lab. Agent Platform is where an agent lives; the SDK
is what an agent can do.

### Dispatch

The agent is a Google API resource, not a public endpoint. The call is
authorized by ADC, in Cloud Shell, the student's own identity. Nothing on the
public internet can reach that resource, so there is no inbound webhook and
nothing inbound needs provisioning.

The lab dispatches through **`geap`**, the MCP server preflight installs, from
inside `agy`: `list_agents` to find the engine, `start_query` with the job as a
JSON string, then `read_query` in a loop against the cursor it returns.
`scripts/dispatch.sh` in the lab repo is the same call in shell.

Two things shape that route. The engine is a **container**, so the platform's
`:streamQuery` returns 404 for it and the call goes to the container's own
`stream_reasoning_engine` route under the project *number*; a 404 on a URL
built from the right project and region reads like a missing agent rather than
a wrong endpoint. And the invocation is capped at **600 seconds**, hard, so
dispatch submits and polls rather than holding the connection. Closing it does
not stop the agent, which is why the branch and not the stream is the display.

### Region

"Location" is three values, and they are not interchangeable.

| Value | Names | The lab pins |
| --- | --- | --- |
| Model location | Which endpoint serves the model | `MODEL_LOCATION=global` |
| Engine location | Where the engine runs, and where Sessions live | `AGENT_ENGINE_LOCATION=us-central1` |
| Deploy region | Where the deploy lands | `AGENT_ENGINE_LOCATION` |

The model is **`gemini-3.6-flash`**, which is served *only* from `global`. So
`MODEL_LOCATION=global` is a requirement of the model, not a preference, and it
stays independent of the engine region. Setting both to `us-central1`, the
tidy-looking mistake, returns 404.

`global` is a model endpoint, not a region. The whole Gemini 3 family is served
only from it, and a regional endpoint returns **404** naming the model, which
reads as a bad model name rather than a bad location. Interpolated into a
regional host it yields `global-aiplatform.googleapis.com`, which does not
resolve; the global host is plain `aiplatform.googleapis.com`.

Model IDs use **dots**: `gemini-3.6-flash`. The hyphenated forms in
documentation URLs are page slugs and 404 the same way a wrong region does.
`gemini-3.6-flash` carries no `-preview` suffix, which matters because preview
models are allowlisted per project and attendees run in their own.

**Neither variable has a default.** A guessed region builds a URL that resolves
and points somewhere else, the agent is reachable and its sessions come back
empty, with nothing indicating why. Preflight refuses to continue if either is
unset.

### Agent runtime

The working copy is ephemeral. `/tmp` is tmpfs and counts against memory, so
pytest and the app's dependencies are baked into the container image and the
clone is shallow. **The durable state is the branch, not the filesystem**, a
third category beside Sessions and Memory Bank: externalised artifacts.

Start at 2 GB and measure; 1–2 vCPU is ample, since the loop is model-latency
bound. The agent iterates until the contract test passes, bounded by a deadline
derived from the invocation timeout rather than an attempt count, it pushes
what it has when the clock runs out.

### Push credentials

The agent pushes with a **deploy key**, an SSH key scoped to one repository,
created with the `gh` credentials the student already has:

```bash
ssh-keygen -t ed25519 -f agent_key -N ""
gh repo deploy-key add agent_key.pub --allow-write --title "health-scorer-agent"
```

The key goes into Secret Manager and is wired to the agent. Blast radius is one
repository by construction.

## Skills

Two distribution mechanisms, because they are two different conversations:

- The **adversary skill and the `contract-writer` subagent** ship in the lab
  repo, the one the attendee forks, as workspace components under `.agents/`.
  One definition, in the repository the run happens in.
- **`local-spec-rules`** is the extension point rather than a step. The
  published skill goes looking for it, so a team adds a rule from their own
  experience without forking the skill: five lines of markdown, no approval,
  no release.

The published skill declares the seam that makes this deterministic:

```markdown
## Local rules
Before reviewing, check for `docs/local-spec-rules.md`.
If it exists, read it and apply those rules in addition to these.
```

The attendee's rule fires because the published skill went looking for it, not
because a model connected two files on its own. That is also the governance
pattern in miniature: a published standard with a documented hook, extended
without forking.

Both are workspace components, discovered relative to where `agy` starts, so
the lab's instruction is to start it from the clone of the fork and there is
nothing to install. That is also why they are readable: an attendee can open
the rules they are about to be refused by, and change them afterwards.

A skill is only its `name` and `description` until something activates it; the
body is loaded on demand. The description is what earns the invocation, so it
is written to be matched, not to be read.

Beside it in the lab repo is the **`contract-writer`** subagent. Writing the
tests is a different job from interrogating the spec, and the adversary kept
sliding from the first into the second, because a skill is guidance the model
can decide the moment has moved past. A subagent cannot: its instructions are
what it is. The adversary invokes it, and if it reports an assertion it could
not derive, that is an ambiguity the interrogation missed and the loop reopens.

## Repos

One rule decides which repo a thing belongs in: **do students fork it?**

| Repo | Students | What it is | Contents |
| --- | --- | --- | --- |
| `workshop-agentic-sdlc` | Clone and install from. Never fork | **Preflight and materials** | This README, `guides/` and the `setup.lab.md` / `setup.tutorial.md` it renders, `scripts/preflight.sh`, `terraform/` |
| `workshop-agentic-sdlc-lab` | Fork on the day | **Where the workshop day is spent** | The app, `docs/request.md`, `docs/spec.md`, `.agents/` with the skill and the subagent, `coder-agent/`, `scripts/`, `lab.lab.md`, the codelab on Pages |

If it is used before the session, it belongs in the first. If the attendee
touches it during the session, it belongs in the second, which is why the
deployed agent lives in the lab repo rather than beside the Terraform.

The lab repo opens at kickoff. The rubric and the walkthrough are where the
lab's discoveries live, and a student who read them last week does not get to
make them.

## Before the session

Attendees need a GCP project with billing enabled and a GitHub account.

### The toolchain

Four things must be on the attendee's path before the lab, and two of them pull
from the public internet:

| Tool | Installs | Needs |
| --- | --- | --- |
| `agy` | `brew install --cask antigravity-cli` | The binary is **`agy`**, not `antigravity` |
| `uv` | astral installer | Prerequisite of `agents-cli` |
| Node / `npx` | preinstalled in Cloud Shell | Prerequisite of the skills installer |
| `agents-cli` + ADK skills | `agents-cli setup` | `uv`, `npx`, github.com, the npm registry |

`agents-cli setup` does double duty: it installs the CLI with
`uv tool install google-agents-cli`, detects installed coding agents, and
installs the ADK skills into them with
`npx -y skills add https://github.com/google/agents-cli -g`. It detects
Antigravity and links the skills into `~/.gemini/config/skills` and
`~/.gemini/antigravity-cli/skills`.

Without those skills the attendee has a coding agent that does not know how to
scaffold, evaluate, or deploy an ADK agent. It is also the step with the most
ways to fail, because it reaches npm *and* GitHub before the fork is ever
involved. How much the lab leans on it is worth measuring: the day's `agy` work
is the adversary, the subagent, and `geap`, and the deploy is a plain
`agents-cli` command rather than a skill.

### Authoring the guides

Each guide has **one source**, `guides/<name>.md.hbs`, rendered into both
formats:

The renderer lives in the private `agentic-sdlc-presenter` repo, cloned beside
this one, so that one copy serves both guide repos:

```bash
cd ../agentic-sdlc-presenter
bash scripts/publish.sh setup   # renders, exports, and adds the copy buttons
```

| Output | Format | Read |
| --- | --- | --- |
| `<name>.lab.md` | CLaaT codelab | anywhere, published to Pages via `claat export -o docs` |
| `<name>.tutorial.md` | Cloud Shell walkthrough | in the Cloud Shell side panel |

**Edit the `.hbs`, never the outputs**, they carry a generated header and are
overwritten by the next build.

The two formats agree on Markdown and on `##` marking a step, and disagree
about everything else. `{{step "Title" 2}}` and `{{#aside "positive"}}` paper
over the markup differences; `{{#codelab}}` and `{{#walkthrough}}` exist for
the differences that markup cannot fix, where the reader's situation is
genuinely different, a walkthrough reader is already in Cloud Shell with the
repository cloned, so telling them to click **Open in Cloud Shell** is not a
formatting problem but a wrong instruction.

Node is needed only to author. Nothing an attendee runs depends on it.

### `preflight.sh`

The attendee-facing instructions are the **setup codelab**, `setup.lab.md`,
which is published before the session and works on a laptop as well as in
Cloud Shell. This section is the design behind it, not a second copy of it.

Clone this repo and run `bash scripts/preflight.sh` **before the session**. It:

- checks authentication, **billing before anything else** (its absence surfaces
  later as `403 BILLING_DISABLED` from a call that never mentions billing),
  required APIs, and `gh` login
- prints the exact command to fix anything missing
- verifies `agy`, `uv`, and `npx` are present, and names the install command for
  any that are not
- runs `agents-cli setup` and verifies the ADK skills landed in Antigravity's
  skill directory
- clones **`geap-mcp`**, the MCP server the lab dispatches its deployed agent
  through, registers it with `agy mcp add` and verifies it with `agy mcp list`,
  both of which work without logging in. Registered as a user server rather than
  through a plugin, because a managed Google account never launches a
  plugin-provided one
- validates `AGENT_ENGINE_LOCATION` and `MODEL_LOCATION` by **making a real call
  to `gemini-3.6-flash`**, not by reading the model catalog. A catalog entry
  describes the model, not your access to it
- exports `GOOGLE_APPLICATION_CREDENTIALS`, because Terraform ignores
  `CLOUDSDK_CONFIG` and would otherwise run as a different account than every
  `gcloud` call beside it
- runs `terraform apply` for the static infrastructure: the required APIs, an
  empty Secret Manager secret, and one IAM binding granting the agent's
  federated principal read access to it

It does **not** check org policy or quota. Neither is cheaply readable by an
attendee, and preflight claims only what it actually verifies: the secret's
user-managed replication is what a resource-location policy would block, so the
apply is that test.

The deployed agent runs under **Agent Identity** rather than a service account,
so nothing here creates one and no grant names a service agent. Its principal is
federated, and the secret is granted to the set covering every Agent Runtime
agent in the project, a member with no engine id in it, which is what lets the
grant precede the engine by a week.

Never mask a grant with `|| true`, and never guess a principal. Both produce the
same failure: a binding that is accepted, grants nothing, and surfaces as an
unexplainable 403 during the lab. Terraform refuses rather than guessing when it
cannot derive the trust domain.

The split is by what a step touches. **Anything touching only your GCP project
runs a week early. Anything touching your fork must wait**, because the fork
does not exist yet. Day-of steps address resources by deterministic name rather
than Terraform outputs, so it does not matter where or when preflight ran.

Both of the lab's day-of blockers retire here: enabling APIs costs 10–15
minutes the lab does not have, and a failed skill or MCP server install sits
directly upstream of the tool that produces the contract. A room where
`agents-cli setup` failed silently is a room with no working agent toolchain,
discovered at the worst possible moment.

`preflight.sh` is re-runnable and reports nothing anywhere. Its output is for
the attendee, and a nudge from the session sponsor is what moves completion.

## On the day

```bash
gh auth login                                                  # device code
gh repo fork OWNER/workshop-agentic-sdlc-lab --clone --remote
```

Then you deploy the agent that ships in the fork with `agents-cli deploy
--agent-identity`, and the deploy key is created and written into the secret.

## Pacing

The lab has one hard gate: **dispatch**. The agent needs wall-clock time to
work, so an attendee who has not dispatched by the stated minute cannot reach
step 12 at all. Everything else can slip.

The lab repo carries one checkpoint branch for anyone behind,
`checkpoint/6-contract-committed`, which is a facilitator's to hand out rather
than a line in the guide. `agentic-sdlc-presenter/notes/recovery.md` has how
and when.

Fast finishers hunt a second seeded ambiguity, or change what the adversary
refuses to decide for them.

## Open questions

- **Timing.** The lab is 60 minutes of content in a 90-minute half. That slack
  is the only slack, and the customer has a next meeting.
- **Reachability.** The fork, the deploy key, and the agent's push all assume
  `github.com`. An enterprise network that blocks it takes the lab to zero.
- **Cloud Shell sizing** for the CLI. Cloud Workstations is the upgrade path.
