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

90 minutes. The guide is a codelab; the work happens in Cloud Shell Editor,
launched from an **Open in Cloud Shell** button inside it.

`lab.lab.md` is authored in DevSite CLaaT format and rendered with `claat
export` to GitHub Pages, so it looks like any other Google codelab — step
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

| Half | Written by | Contract |
| --- | --- | --- |
| `usage.py` | The deployed agent, unsupervised | `parse_usage(csv) -> list[MonthSnapshot]` |
| `score.py` | The local agent, steered by you | `score(list[MonthSnapshot]) -> (score, tier, reasons)` |

Nobody hand-writes Python. Both halves are agent-written; what differs is
whether anyone is watching.

`MonthSnapshot` is the seam. The spec fixes it, along with the exact weights
and tier thresholds, so that two parties working independently arrive at code
that fits.

### The contract

Three tests, emitted by the spec adversary and committed before either party
starts. A contract is testable from both sides independently — that is what
makes it a contract rather than a wish.

| Test | Verifies | Asserts |
| --- | --- | --- |
| `test_parse_contract.py` | The deployed half, alone | `parse_usage(FIXTURE)` produces exactly this `list[MonthSnapshot]` |
| `test_score_contract.py` | The local half, alone | `score(<longhand MonthSnapshot list>)` produces exactly this tier and reasons |
| `test_integration.py` | Both, after merge | The two compose |

The longhand `MonthSnapshot` list in your test is the seam, written out by hand.

### The steps

`Duration:` tags sum into the codelab's navbar, so the budget is visible to the
attendee throughout.

| # | Step | Duration |
| --- | --- | --- |
| 1 | Before you begin | — |
| 2 | Fork the lab and connect your agent | 0:08 |
| 3 | Scaffold the coder agent and start its deploy | 0:05 |
| 4 | File the request | 0:03 |
| 5 | **Grill the spec** | 0:15 |
| 6 | Take the contract | 0:03 |
| 7 | Dispatch, and watch both agents work | 0:08 |
| 8 | Integrate and verify | 0:04 |
| 9 | Teach the adversary a rule of your own | 0:06 |
| 10 | Eval the adversary | 0:04 |
| 11 | Clean up | 0:03 |
| 12 | Congratulations | — |
| | **Total** | **59 min** |

Fifty-nine minutes of content in the ninety-minute half. The slack is
deliberate: this runs in a customer's environment, which nobody has tested.

**Step 3 starts the deploy and walks away.** It runs while steps 4–6 happen, and
step 7 verifies it before dispatching. Waiting for a deploy teaches nothing.

**Step 5 is the lab.** The adversary surfaces one ambiguity at a time and shows
both readings and how they diverge — *empty `seats_active`: zero, so the account
collapsed, or unknown, so skip the month?* You choose. It writes your choice
into the spec and moves on. It finds them; **you** decide them.

**Step 7 is what they came to see.** Two agents building one feature from one
contract, neither able to see the other. The local one you steer; the deployed
one nobody does.

**Step 8 is the point.** It fits because the contract was precise, not because
anyone coordinated. Attendees who resolved an ambiguity differently still
succeed — the adversary encoded *their* decision into *their* contract, and both
agents coded against it. The lab does not require the right answer. It requires
an answer, written down before work starts.

Then the debrief line: *fifteen minutes deciding, five minutes building, and it
fit first time. Which half did you expect to be the work?*

## Architecture

Where a thing runs follows from what it does.

| Party | Runs | Why there |
| --- | --- | --- |
| Spec adversary | Local, Antigravity CLI skill | Interactive, high-iteration, ephemeral. A round trip per turn would ruin it |
| Local coder | Local, Antigravity CLI | Supervised. You approve each turn, so **you** are the contract |
| Deployed coder | Agent Platform | Unsupervised, and working at the same time as you. **The test** is the contract |

That contrast is the lab's argument: you can only let an agent work
unsupervised if something other than you is holding it to the spec.

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
| Model location | Which endpoint serves the model | `MODEL_LOCATION=global` |
| Engine location | Where the engine runs, and where Sessions live | `AGENT_ENGINE_LOCATION=us-central1` |
| Deploy region | Where the deploy lands | `AGENT_ENGINE_LOCATION` |

The model is **`gemini-3.6-flash`**, which is served *only* from `global`. So
`MODEL_LOCATION=global` is a requirement of the model, not a preference, and it
stays independent of the engine region. Setting both to `us-central1` — the
tidy-looking mistake — returns 404.

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
- **`local-spec-rules`** the attendee writes themselves in about five minutes —
  a rule from their own team's experience, added to the adversary. That is the
  authoring story: five lines of markdown, no approval, no release.

The published skill declares the seam that makes this deterministic:

```markdown
## Local rules
Before reviewing, check for `skills/local-spec-rules.md`.
If it exists, read it and apply those rules in addition to the standard set.
```

The attendee's rule fires because the published skill went looking for it, not
because a model connected two skills on its own. That is also the governance
pattern in miniature: a published standard with a documented hook, extended
without forking.

The skill source lives here in `skills/`, alongside a root `plugin.json` that
makes this repo installable with `agy plugin install .`. If the plugin install
fails, the file is already on disk in a repo they cloned a week ago — one copy
command, and nothing sat in the lab repo's discovery path in the meantime.

A skill is only its `name` and `description` until something activates it; the
body is loaded on demand. The description is what earns the invocation, so it
is written to be matched, not to be read.

## Repos

One rule decides which repo a thing belongs in: **do students fork it?**

| Repo | Students | What it is | Contents |
| --- | --- | --- | --- |
| `workshop-agentic-sdlc` | Clone and install from. Never fork | **Preflight and materials** | This README, classroom outline, `guides/` and the `setup.lab.md` / `setup.tutorial.md` it renders, `scripts/preflight.sh`, `terraform/`, `skills/` |
| `workshop-agentic-sdlc-lab` | Fork on the day | **Where the workshop day is spent** | The app, `docs/request.md`, `docs/spec.md`, `coder-agent/`, `scripts/setup-deploy-key.sh`, `lab.lab.md`, the codelab on Pages |

If it is used before the session, it belongs in the first. If the attendee
touches it during the session, it belongs in the second — which is why the
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
scaffold, evaluate, or deploy an ADK agent — which is most of the lab. This is
the single highest-value thing preflight does, and the one with the most ways
to fail, because it reaches npm *and* GitHub before the fork is ever involved.

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

**Edit the `.hbs`, never the outputs** — they carry a generated header and are
overwritten by the next build.

The two formats agree on Markdown and on `##` marking a step, and disagree
about everything else. `{{step "Title" 2}}` and `{{#aside "positive"}}` paper
over the markup differences; `{{#codelab}}` and `{{#walkthrough}}` exist for
the differences that markup cannot fix, where the reader's situation is
genuinely different — a walkthrough reader is already in Cloud Shell with the
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
- installs the `spec-adversary` plugin and verifies it loads with
  `agy plugin list`, which works without logging in
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
agent in the project — a member with no engine id in it, which is what lets the
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
minutes the lab does not have, and a failed skill or plugin install sits
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

- **Timing.** The lab is ~73 minutes of content in a 90-minute half. That slack
  is the only slack, and the customer has a next meeting.
- **`claat`.** Verify the export invocation and that the generated output serves
  correctly from Pages before building the guide around it.
- **Reachability.** The fork, the deploy key, and the agent's push all assume
  `github.com`. An enterprise network that blocks it takes the lab to zero.
- **Agent Runtime's maximum invocation duration.** If it is shorter than a
  red-to-green loop, dispatch changes from streaming to submit-and-poll.
- **Cloud Shell sizing** for the CLI. Cloud Workstations is the upgrade path.
