# Set up your project, before the workshop

This prepares **your own Google Cloud project** for the session. It runs a
week early on purpose, so nothing here competes with the lab for time.

Nothing you do here is reported anywhere. The output is for you.

By the end you will have: a project with the right APIs on, an empty Secret
Manager secret waiting for a deploy key, the `agy` CLI updated and logged in,
and the `spec-adversary` plugin installed.

**You do not fork this repository.** You clone it, you run preflight from it,
and on the day you fork a *different* one — `workshop-agentic-sdlc-lab`.

## Pick your project

<walkthrough-tutorial-duration duration="2"></walkthrough-tutorial-duration>

Use a project you are happy to create billed resources in. The lab deploys an
agent, which costs money while it runs, and the last step of the workshop
tears it down again.

<walkthrough-project-setup></walkthrough-project-setup>

The picker sets a tutorial variable, not your shell. Apply it:

```bash
export GOOGLE_CLOUD_PROJECT="<walkthrough-project-id/>"
gcloud config set project "$GOOGLE_CLOUD_PROJECT"
gcloud config get-value project
```

**Billing must be linked to this project.** Preflight checks it early, because
without it the Agent Platform APIs fail with `403 BILLING_DISABLED` from a call
that never mentions billing.

## Authenticate

<walkthrough-tutorial-duration duration="2"></walkthrough-tutorial-duration>

A fresh Cloud Shell session starts with no credentials. You need **two** grants
here, not one — the second is what Terraform uses:

```bash
gcloud auth login --update-adc
```

`--update-adc` is the part that matters. Application Default Credentials are a
separate file from your `gcloud` login, and Terraform reads only the former.

## Choose your two locations

<walkthrough-tutorial-duration duration="2"></walkthrough-tutorial-duration>

Two settings, and they are **not** the same value:

| Variable | Value | What it controls |
| --- | --- | --- |
| `MODEL_LOCATION` | `global` | Where the model answers from |
| `AGENT_ENGINE_LOCATION` | `us-central1` | Where your agent runs |

```bash
export MODEL_LOCATION=global
export AGENT_ENGINE_LOCATION=us-central1
```

**Setting both to the same thing is the mistake to avoid.** The workshop uses
`gemini-3.6-flash`, and the whole Gemini 3 family is served *only* from
`global` — a regional endpoint returns a 404 that names the model and reads
like a typo. Preflight refuses to continue if the two match, or if either is
unset. There are deliberately no defaults: a guessed region builds a URL that
resolves and quietly points somewhere else.

Add both to `~/.bashrc` if you want them to survive a new session.

## Update agy

<walkthrough-tutorial-duration duration="2"></walkthrough-tutorial-duration>

Cloud Shell ships `agy` at `/usr/bin/agy`, and the version varies by session —
1.1.9 and 1.1.13 have both been seen minutes apart. The workshop runs on the
current release so everyone is on the same one.

**This is an every-session step.** `agy update` replaces the binary in
`/usr/bin`, which lives on the VM rather than the persistent disk, so it is
discarded whenever Cloud Shell recycles. If you reconnect later, run it again —
and if anything misbehaves afterwards, check `agy --version` first.

It needs `sudo`, because the unprivileged updater refuses with
`directory /usr/bin is not fully accessible`. Cloud Shell grants passwordless
sudo. It takes about 20 seconds, and the download happens on the Cloud Shell
VM rather than over your own connection.

```bash
sudo agy update && agy --version
```

## Authenticate agy

<walkthrough-tutorial-duration duration="3"></walkthrough-tutorial-duration>

**`agy` has its own login, separate from `gcloud`.** Authenticating gcloud does
nothing for it — it holds its own OAuth grant with its own scopes. Two logins,
not one. There is no `agy login` subcommand; authentication happens on first
use.

**Maximise the terminal panel first.** The login prints a very long URL, and a
narrow terminal wraps it across six or more lines, which is painful to select.

Use plain `agy`, **not** `agy -p`. Print mode caps the wait at 60 seconds and
then fails with `authentication interrupted`. The interactive prompt has no
timeout — it waits at an input field for as long as you need.

```bash
agy
```

You will be asked to open a URL, then to paste back a code. The URL is emitted
as a terminal hyperlink, so **try clicking it first**. Approve in the browser,
copy the code, paste it into the `authorization code...` field, press Enter,
then leave with `/quit`.

The browser need not be on this machine: the redirect goes to a hosted
callback rather than a localhost listener, which is what makes this work in
Cloud Shell at all.

Confirm the grant took:

```bash
agy -p "Reply with exactly: authenticated"
```

<walkthrough-footnote>
Answering without a URL prompt means the grant is in place. Unlike the binary,
it lives under ~/.gemini and does survive a session recycle.
</walkthrough-footnote>

## Run preflight

<walkthrough-tutorial-duration duration="4"></walkthrough-tutorial-duration>

This checks everything above, then provisions the project.

Look first if you like — it changes nothing with `--plan-only`:

```bash
bash scripts/preflight.sh --plan-only
```

Then run it for real:

```bash
bash scripts/preflight.sh
```

It checks your tools, that npm and github are reachable, that billing is
linked, that the APIs are on, and that `gemini-3.6-flash` really answers for
you — with an actual call, because a catalog entry describes the model rather
than your access to it. Then it applies the Terraform.

**Failures do not stop it.** Every problem it finds is listed at the end with
the exact command that fixes it, so you get the whole list in one run. Fix
them and run it again — it is safe to re-run.

<walkthrough-footnote>
If you are on a corporate network, the checks most likely to fail are npm and
github reachability. Those are needed before any Google Cloud resource is
involved, because the ADK skills install through npx.
</walkthrough-footnote>

## You are ready

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

Preflight created an **empty** secret named `agentic-sdlc-deploy-key`. It stays
empty until the day — the key goes into it during the lab, generated against
the repository you will fork then.

Nothing is running yet, so nothing is costing you anything. The agent gets
deployed during the session, and the final step of the lab tears it down.

If you had to fix anything, re-run `bash scripts/preflight.sh` until it
reports **ready**. Bring that result to the session.
