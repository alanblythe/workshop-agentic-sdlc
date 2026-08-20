# LAB-02 — Agent Runtime findings

**Status: partial.** Model availability is settled. The runtime limits still
need a project — see Outstanding.

Locations chosen for the workshop:

| Variable | Value |
|---|---|
| `AGENT_ENGINE_LOCATION` | `us-central1` |
| `MODEL_LOCATION` | `global` |
| Model | `gemini-3.6-flash` |

`gemini-3.6-flash` is GA (no `-preview` suffix), so it carries no per-project
allowlist risk in an attendee's own project — the deciding factor. It is served
only from `global`, which is what fixes `MODEL_LOCATION`.

## Projects

Argolis org `ablythe.altostrat.com` (`1085975473437`), billing
`014BB1-D8854B-6BF307`.

| Project | Number | Role |
|---|---|---|
| `agentic-sdlc-ws1` | 622097863668 | Build and iterate |
| `agentic-sdlc-ws2` | 99705347531 | Rehearsal — kept pristine |

`ws2` has billing linked and **no APIs enabled**. That is deliberate: the
rehearsal (LAB-19/20) exists to prove a *fresh* project works, and a project
already warmed by the build cannot demonstrate that. Do not enable anything in
`ws2` outside a rehearsal run.

`ws1` has `aiplatform`, `run`, `cloudbuild`, `storage`, `secretmanager`,
`iam`, and `iamcredentials` enabled. LAB-05 owns the canonical list; this set
is what LAB-02 needed.

The repo pins the project through a gitignored `.envrc`
(`CLOUDSDK_CORE_PROJECT`) rather than `gcloud config set`, because the
altostrat profile's active project is shared with the luncher repo.
`AGENT_ENGINE_LOCATION` and `MODEL_LOCATION` are deliberately **not** exported
there — preflight must refuse when they are unset, and exporting them locally
would hide a regression in that check.

### The two AI Platform service agents are not the same principal

```
gcloud beta services identity create --service=aiplatform.googleapis.com
  -> service-622097863668@gcp-sa-aiplatform.iam.gserviceaccount.com
```

That creates **`gcp-sa-aiplatform`**. The Agent Runtime principal is
**`gcp-sa-aiplatform-re`** — a different service agent, still lazily created.
A Terraform grant to the `-re` principal on a fresh project can therefore fail
with `INVALID_ARGUMENT: ... does not exist` even after this command has run.
Never mask that grant with `|| true`; it will silently produce an agent that
deploys and then cannot do its job.

## Model availability — `global` is required, not preferred

Measured 2026-08-20 with `generateContent`. Confirmed identically in the
workshop project `agentic-sdlc-ws1` and in `geap-3a-token-sec`, so the pattern
is a property of model serving, not of one project's allowlist:

| Model | `global` | `us-central1` |
|---|---|---|
| `gemini-3.1-pro-preview` | 200 | **404** |
| `gemini-3.6-flash` | 200 | **404** |
| `gemini-3.5-flash` | 200 | **404** |
| `gemini-2.5-flash` | 200 | 200 |

**The whole Gemini 3 family is served only from `global`.** Only the 2.5
generation still answers a regional endpoint. `MODEL_LOCATION=global` is
therefore a requirement of using a Gemini 3 model, not a preference — and
`AGENT_ENGINE_LOCATION` being `us-central1` does not change it. The two are
independent values and the lab must keep them independent.

The failure is a **404 whose message names the model**:

```
Publisher model `projects/P/locations/us-central1/publishers/google/models/gemini-3.6-flash` was not found
```

which reads as a typo rather than a location error. This is the concrete case
the guide should warn about, because it is what an attendee who "helpfully"
sets both variables to the same region will hit.

Reminder from the platform notes: `global` is a **model endpoint, not a
region**. Never interpolate it into a hostname —
`global-aiplatform.googleapis.com` does not resolve. The global endpoint host
is plain `aiplatform.googleapis.com`.

## Model IDs use dots, not hyphens

`gemini-3.1-pro-preview`, `gemini-3.5-flash`, `gemini-3.6-flash`.

Google's *documentation URLs* render these as slugs like `gemini-3-1-pro` and
`gemini-3-pro-preview`. **Those are page slugs, not model IDs.** A slug used as
a model ID 404s identically to a wrong region, which is how the two mistakes
get confused for each other.

## `-preview` models are allowlisted per project

A catalog listing of `CAN_PREDICT: Yes` describes the entry, not your access;
preview models are enabled per project. `gemini-3.1-pro-preview` answers in
`geap-3a-token-sec` but that says nothing about a customer's project.

**Prefer a GA model for anything an attendee runs.** The lab puts attendees in
their own projects, where a preview allowlist is exactly the variable we do not
control, and the symptom is again a 404 that reads as a bad model name.
`preflight.sh` (LAB-04) should make a real call to the chosen model rather than
consult the catalog — only a real call settles it.

Prior art: `~/repos/ensemblr/docs/reference/README.md` records the same lesson
after a preview-model 404 broke a staging deploy.

## Deploy and runtime

| Measure | Value |
|---|---|
| Cold deploy, `agents-cli deploy` | **7m13s** |
| Create an engine sourceless, to mint an identity | ~20s |

Lab step 3 must treat a deploy as a background task with something else filling
the time. It is not a step anyone can watch.

Deploy defaults: memory `4Gi`, CPU `1`, min instances `1`, max `10`, container
concurrency `8`.

The deploy is also what creates the `gcp-sa-aiplatform-re` service agent —
`service-622097863668@gcp-sa-aiplatform-re.iam.gserviceaccount.com` appeared
only after it completed.

### The container

From inside a running engine:

- Root is **`overlay`**, `upperdir=/tmp/fs/0/upper`. There is no separate
  `/tmp` mount.
- **`/tmp` is sized to the memory limit** — exactly 4096 MiB at `--memory 4Gi`.
  Scratch files compete with the process for the memory budget.
- `/dev/shm` is a real `tmpfs`.

## Outstanding

### Maximum invocation duration — the blocker, still unmeasured

Work exceeding roughly 600s returned `503` while shorter work returned `200`,
but **every reading so far is untrustworthy** and the figure must not be
designed around yet.

The instrument was wrong. `probe_sleep` used a blocking `time.sleep()`, which
stalls the async event loop, so `container_concurrency: 8` bought nothing and
five parallel probes wedged the single instance. Killing the clients did not
cancel the server-side work. A subsequent one-word request returned `HTTP 000`
after 180s, which is how the saturation was caught: the timings were measuring
that queue, not the platform.

Two questions remain open, and they have different consequences:

1. **Is the ceiling a cap on total invocation, or an idle timeout?**
   `:streamQuery` streams NDJSON, and a single silent tool call emits nothing
   for its whole duration — indistinguishable from a dead connection. A real
   red-to-green loop is chatty, so if the ceiling is idle-based it may never be
   reached in practice.
2. **Does `curl -o file` even measure the right thing?** It times connection
   close, not answer arrival.

The tool is now `async` (`await asyncio.sleep`). The test that settles it: on a
fresh instance, have the agent call a short tool repeatedly so events land
every ~60s across a total well past 600s. Surviving that means idle-based and
LAB-13 stands as designed; dying at ~600s with events flowing means a hard cap
and LAB-13 becomes submit-and-poll.

### Also outstanding

- Whether the runtime reaches `github.com` over SSH for the agent's push
  (`probe_github` is deployed but has not been run)
