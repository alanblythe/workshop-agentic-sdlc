<!-- Generated from guides/setup.md.hbs by the presenter repo. Do not edit. -->
# Agentic SDLC workshop: set up your project

<walkthrough-tutorial-duration duration="19"></walkthrough-tutorial-duration>

## Before you begin

<walkthrough-tutorial-duration duration="1"></walkthrough-tutorial-duration>

This prepares **your own Google Cloud project** for the Agentic SDLC
workshop. Do it any time before the session. It takes about twenty minutes,
and nothing here competes with the lab for time on the day.

Nothing you do is reported anywhere. The output is for you.

### What you'll need

- A Google Cloud project **with billing enabled**, where you are happy to
  create billed resources
- A GitHub account, and the `gh` CLI logged in
- Either Cloud Shell, or a laptop with `gcloud`, `terraform`, `uv`, `gh` and
  Node installed

### What you'll end up with

- The required APIs enabled on your project
- An **empty** Secret Manager secret, waiting for a deploy key
- `agy` updated and authenticated
- `geap`, the MCP server the lab dispatches its agent through, registered

> **Careful:**
>
> **Do not fork this repository.** You clone it and run preflight from it. On
> the day you fork a *different* repository, the lab one. Forks do not copy
> issues, and the lab repo stays sealed until kickoff.

## Get the repository

<walkthrough-tutorial-duration duration="2"></walkthrough-tutorial-duration>

You already have it. This tutorial is being read from the clone Cloud Shell
made when you opened it, and the shell below is sitting in that directory.

> **Tip:**
>
> Tick **Trust repo** when Cloud Shell asks. It is remembered, and it is what
> gives you a normal session with your real home directory rather than an
> ephemeral one that discards anything you install.

## Point at your project and authenticate

<walkthrough-tutorial-duration duration="2"></walkthrough-tutorial-duration>

Pick the project you want to use:

<walkthrough-project-setup></walkthrough-project-setup>

> **Tip:**
>
> Every command block in this panel has a terminal icon above it. Clicking it
> puts the command at the prompt in the shell below, so you never have to copy,
> switch focus and paste. The icon beside it copies instead, for the times you
> want to edit the command first.

Then point `gcloud` at it:

```bash
gcloud config set project <walkthrough-project-id/>
gcloud config get-value project
```

Then authenticate. You need **two** grants here, not one:

```bash
gcloud auth login --update-adc
```

`--update-adc` is easy to miss. Application Default Credentials are a
separate file from your `gcloud` login, and Terraform reads only that file,
never your `gcloud` configuration.

> **Careful:**
>
> If you keep more than one `gcloud` configuration and switch with
> `CLOUDSDK_CONFIG`, note that **Terraform ignores it entirely**. It reads
> `GOOGLE_APPLICATION_CREDENTIALS`, then a fixed path. Preflight handles this
> for you, but it explains an error that claims your project does not exist.

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

> **Careful:**
>
> **Do not set both to the same value.** The workshop uses `gemini-3.6-flash`, and the whole Gemini 3 family is served
> *only* from `global`. A regional endpoint returns a 404 that names the model,
> so it reads like a typo in the model name rather than a wrong location.

Preflight refuses to run if either is unset, or if the two match. There are no
defaults on purpose: a guessed region builds a URL that
resolves, and points somewhere else.

Add both to `~/.bashrc` if you want them to survive a new shell.

## Update agy

<walkthrough-tutorial-duration duration="2"></walkthrough-tutorial-duration>

Cloud Shell ships `agy`, but the version varies between sessions. Update it so
everyone is on the same release:

```bash
sudo agy update && agy --version
```

`sudo` is needed because the binary lives in `/usr/bin`; without it the updater
refuses with `directory /usr/bin is not fully accessible`.

> **Careful:**
>
> **Run this every session.** `/usr/bin` is on the VM rather than the persistent
> disk, so the update is discarded when Cloud Shell recycles.

## Install terraform

<walkthrough-tutorial-duration duration="1"></walkthrough-tutorial-duration>

Cloud Shell has a `terraform` on `PATH`, but it is a stub that prints install
instructions and exits 0. Every command appears to succeed while doing
nothing, including the apply that provisions your project. Preflight refuses to
run against it.

```bash
wget -O - https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
```

### Verify your work

```bash
terraform version
```

A real binary answers `Terraform v1.x.x`. The stub prints installation
instructions instead, which is exactly what it did before you started.

## Check gh is logged in

<walkthrough-tutorial-duration duration="1"></walkthrough-tutorial-duration>

On the day you fork the lab repository and add a deploy key to it, both through
`gh`. Cloud Shell ships `gh` but does not sign you in.

```bash
gh auth status
```

If that reports you are not logged in:

```bash
gh auth login
```

Choose GitHub.com, then HTTPS, then authenticating with a browser. `gh` prints
a short one-time code and a `github.com/login/device` URL to enter it at.

> **Tip:**
>
> Preflight checks this as well, but it runs to the end before reporting,
> including the Terraform apply. Fixing it here saves that wait.

## Let Terraform read your project

<walkthrough-tutorial-duration duration="1"></walkthrough-tutorial-duration>

Preflight's Terraform turns on every API this workshop needs, except the one
it needs in order to read the project at all. Turn that one on yourself:

```bash
gcloud services enable cloudresourcemanager.googleapis.com
```

> **Careful:**
>
> Skip this and `terraform plan` prints a plan that looks fine, then fails with
> `Error 403: Cloud Resource Manager API has not been used in project ... before
> or it is disabled`. The plan is not the problem; Terraform could not read the
> project to begin with.

## Run preflight

<walkthrough-tutorial-duration duration="3"></walkthrough-tutorial-duration>

This checks everything above, then provisions your project.

**What it checks, changing nothing:**

- Your two locations are set
- gcloud, terraform, uv, gh, npx, agy
- npm registry and github reachable
- Project readable, billing linked
- `gemini-3.6-flash` answers a real call
- `gh` is logged in

**What it changes:**

- Enables the APIs the lab needs
- Installs the ADK skills
- Registers the `geap` MCP server
- Exports Terraform's credentials
- Creates an empty deploy-key secret

Read it if you like: <walkthrough-editor-open-file filePath="cloudshell_open/workshop-agentic-sdlc/scripts/preflight.sh">scripts/preflight.sh</walkthrough-editor-open-file>. And with
`--plan-only` it reports all of the above and changes none of it:

```bash
bash scripts/preflight.sh --plan-only
```

Then run it for real:

```bash
bash scripts/preflight.sh
```

The model is checked with a real call rather than a catalog lookup, because a
catalog entry describes the model and not your access to it. Applying the
Terraform is the last thing it does.

> **Tip:**
>
> **Failures do not stop it.** Every problem is listed at the end with the exact
> command that fixes it, so you get the whole list in one run rather than
> discovering them one at a time. Fix them and run it again. It is safe to
> re-run, and safe to run in a fresh clone.

### Verify your work

A successful run ends with:

```
== ready ==
  Everything is ready for the lab.
```

If you are on a corporate network, the checks most likely to fail are npm and
github reachability. Both are needed before any Google Cloud resource is
involved, because the ADK skills install through `npx`.

## Authenticate agy

<walkthrough-tutorial-duration duration="3"></walkthrough-tutorial-duration>

`agy` has **its own login, separate from `gcloud`**. Authenticating gcloud does
nothing for it. It holds its own OAuth grant with its own scopes. Two logins,
not one. There is no `agy login` subcommand; authentication happens on first
use.

Do this one in **the editor's terminal**: **View → Terminal**, or `` Ctrl+` ``.
The link you need is not clickable in Cloud Shell's own terminal panel.

```bash
agy
```

It asks how you want to sign in. Either option works here:

- **Google OAuth** — sign in with your Gemini Enterprise account and the project
  that comes with it.
- **Use a Google Cloud project** — point `agy` at the project you have been
  configuring. This needs the Agent Platform API, `aiplatform.googleapis.com`,
  which preflight has just enabled for you.

[The Antigravity enterprise docs](https://antigravity.google/docs/enterprise/)
cover both in full.

Whichever you pick, scroll past the long blue URL and click **Click here to
authenticate** beneath it. Approve in the browser, copy the code it shows,
paste it into the `authorization code...` field, press Enter, then leave with
`/exit`.

![The agy login prompt: a wrapped URL, and below it the line reading 'Click here to authenticate'](https://raw.githubusercontent.com/alanblythe/workshop-agentic-sdlc/main/docs/images/agy-login-click-here.png)

> **Careful:**
>
> **Do not click the long URL above it.** It is wrapped across several rows and
> the wrap is hard, so each row is its own fragment. Clicking one sends half a
> URL, and Google answers `Error 400 (Bad Request)`, `invalid_request` — which
> reads like a broken sign-in rather than a broken link.

Come back to the terminal below afterwards. The terminal icon on each command
block sends there, not to a terminal you opened yourself.

The browser does not have to be on this machine. The redirect goes to a hosted
callback rather than a localhost listener, which is what makes this work in
Cloud Shell.

### Verify your work

```bash
agy -p "Reply with exactly: authenticated"
```

Answering without prompting for a URL means the grant is in place. Unlike the
binary, it lives under `~/.gemini` and does survive a session recycle.

## You're ready

<walkthrough-tutorial-duration duration="1"></walkthrough-tutorial-duration>

Preflight created an **empty** secret named `agentic-sdlc-deploy-key`. It stays
empty until the day: the key is generated against the repository you fork
during the lab, which does not exist yet.

Nothing is running, so nothing is costing you anything. The agent is deployed
during the session, and the last step of the lab tears it all down again.

If you had to fix anything, re-run `bash scripts/preflight.sh` until it reports
**ready**, and bring that result to the session.
