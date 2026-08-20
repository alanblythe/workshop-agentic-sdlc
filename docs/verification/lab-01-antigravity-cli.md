# LAB-01 — Antigravity CLI findings

Verified 2026-08-20 against `antigravity-cli` **1.1.16** on macOS 15 (arm64).

## Install

```shell
brew install --cask antigravity-cli
```

The cask links the binary as **`agy`**, not `antigravity`:

```
Linking Binary 'antigravity' to '/opt/homebrew/bin/agy'
```

**The command attendees type is `agy`.** Three casks exist — `antigravity`
(the app), `antigravity-ide` (binary `agy-ide`), and `antigravity-cli`. The lab
is CLI-only, so `antigravity-cli` is the one prerequisite.

`agy install` is unrelated to plugins — it configures shell PATH and aliases.

## Auth — no localhost redirect

The workstation decision holds. First use of an unauthenticated CLI prints:

```
Authentication required. Please visit the URL to log in:
  https://accounts.google.com/o/oauth2/auth?...&redirect_uri=https%3A%2F%2Fantigravity.google%2Foauth-callback&...

Waiting for authentication (timeout 60s)...
Or, paste the authorization code here and press Enter:
```

The redirect target is the hosted `https://antigravity.google/oauth-callback`,
and the CLI accepts a **pasted authorization code**. Neither requires a
loopback listener, so the browser need not run on the same machine as the CLI.
**Cloud Shell survives as the workstation.**

Two operational details for the guide:

- The wait is capped at **60 seconds**. An attendee who reads the paragraph
  before acting will time out and have to re-run. Tell them to have the browser
  ready before they run it.
- Scopes requested: `cloud-platform`, `userinfo.email`, `userinfo.profile`,
  `cclog`, `experimentsandconfigs`, `aicode`, `openid`. `cloud-platform` is
  broad enough that a customer with a restrictive consent policy may be blocked
  — worth a preflight check (LAB-04).

## The noun is *plugin*; skills live inside one

A **plugin** is the installable unit. **Skills** are one of five component
types it can carry: `skills`, `agents`, `commands`, `mcpServers`, `hooks`.

The sister repo should be named for the plugin, since that is what attendees
install and type.

```
agy plugin list | import | install <target> | uninstall <name>
           enable <name> | disable <name> | validate [path] | link <mp> <target>
```

`install` accepts a **local path** (verified) and `plugin@marketplace`.
`import` pulls from `gemini` or `claude`.

### Layout

```
my-plugin/
  plugin.json                      <- ROOT, not .claude-plugin/
  skills/
    spec-adversary/
      SKILL.md
```

`plugin.json` **must sit at the plugin root.** A `.claude-plugin/plugin.json`
is not found:

```
Error: missing plugin.json: stat .../probe-plugin/plugin.json: no such file
```

This diverges from Claude Code's layout despite the shared component model and
the `plugin import claude` path. `name` is the only required manifest field;
an empty object fails with `plugin.json missing name`.

### SKILL.md frontmatter

`name` and `description` are the documented required keys. Optional:
`disable-slash-command: true`, which hides a skill from the `/` menu and from
`/name` resolution while leaving the model able to invoke it.

A skill is reachable three ways: `/<name>` as a slash command, semantic
discovery by the model, or explicit user activation.

### Progressive loading — confirmed

> Skills are not loaded into the context window by default. Only their
> names and descriptions are injected. The full content of a skill is only
> loaded if the model (or the user) explicitly decides to activate it.

So a skill's `description` is what earns it an invocation. This is the design
constraint for the `spec-adversary` skill in LAB-06.

## Turn-by-turn steering works — lab step 5 is safe

Multi-turn interrogation is supported three ways:

| Flag | Behaviour |
|---|---|
| `--prompt-interactive` / `-i` | Run an initial prompt, then **continue interactively** |
| `--continue` / `-c` | Continue the most recent conversation |
| `--conversation <id>` | Resume a specific conversation by ID |

Skills are not one-shot. `--print` / `-p` is the one-shot mode, and print mode
"already starts a new conversation unless `--continue` or `--conversation` is
passed". `--input-format stream-json` reads NDJSON from stdin and **runs a turn
per line**, which is a scriptable multi-turn path for the rehearsal harness.

Also relevant to later issues: `--mode plan|accept-edits`, `--effort
low|medium|high`, `--output-format text|json|stream-json`, `--json-schema`,
`--sandbox`, `--dangerously-skip-permissions`, and `--print-timeout` (default
**5m0s**).

## Footprint

| Measure | Value |
|---|---|
| Binary on disk | 169 MB |
| RSS at rest | ~88 MB |
| RSS under load | **Not measured** — needs an authenticated session |

The 169 MB binary is the Cloud Shell concern, not the RSS. Cloud Shell
persists `$HOME` only; anything installed outside it is reinstalled every
session. Where `agy` can live in Cloud Shell is a LAB-03 question.

## On Linux / Cloud Shell it is preinstalled — and the version varies

Measured in Cloud Shell (Ubuntu 24.04.4 LTS, Linux 6.6.143+ x86_64).

`agy` ships in the image at **`/usr/bin/agy`**, 197 MB, **not owned by dpkg** —
placed by the image build rather than a package. **There is no install step on
Cloud Shell**, and the 169 MB download this document worried about never
happens there.

| Where | Version |
| :--- | :--- |
| Cloud Shell, ephemeral session | **1.1.9** |
| Cloud Shell, persistent session | **1.1.13** |
| macOS cask | **1.1.16** |

**The version is not merely behind, it is inconsistent between sessions of the
same product.** Two sessions minutes apart reported different versions. Nothing
may depend on a specific `agy` version, and a rehearsal on macOS says nothing
about what an attendee runs.

PATH persistence is a non-issue: `/usr/bin` is on the system PATH, so nothing
needs a shell-profile entry.

### `agy update` works — but writes to `/usr/bin`, so it does not persist

`agy update` took Cloud Shell from **1.1.13 to 1.1.16**, matching the macOS
cask. It updates the binary **in place**:

```
version      : 1.1.16
which        : /usr/bin/agy
```

**`/usr/bin` is on the VM, not the persistent disk.** Cloud Shell persists only
`$HOME` and rebuilds the rest, so the update is discarded whenever the VM
recycles. Nothing lands in `~/.local/bin`.

So updating is **an every-session step, not a preflight one**. Preflight cannot
do it a week early and have it stick.

**Which raises whether the lab should update at all.** The behaviour LAB-06
depends on — root `plugin.json`, install-by-path, the
`~/.gemini/config/plugins/` target, unauthenticated `plugin list` — is
identical on 1.1.9, 1.1.13 and 1.1.16. Running latest costs every attendee a
step every session and buys nothing yet measured.

**Recommendation: do not update in the lab.** Pin the guide to what the image
ships, and re-verify the plugin behaviour against the image version during the
rehearsal (LAB-19/20). Add an update step only if a specific needed behaviour
turns out to be missing — and if that happens, the step has to be repeated by
every attendee on every reconnect, which is worth knowing before designing
around it.

### Authentication is a second login, and it works

After the interactive login, the probe's print-mode call answered directly:

```
== auth state / prompt shape ==
ok
[exit 0]
```

`gcloud auth login --update-adc` does **not** authenticate `agy`; they hold
separate grants with separate scopes. The lab needs both.

The grant lives under `~/.gemini`, which is persistent — so unlike the binary
update, authentication *does* survive between sessions.

### The plugin layout works on the Cloud Shell version

This is the compatibility question LAB-06 depended on, and the answer is yes.
On **1.1.13**, installing this repo by path behaves exactly as on 1.1.16:

```
$ agy plugin install ~/cloudshell_open/workshop-agentic-sdlc-0
  [ok]    spec-adversary
          ✔ skills      : 1 processed
$ agy plugin list        # unauthenticated, JSON
  ... "name": "spec-adversary", "components": ["skills"]
→ /home/blythe_alan/.gemini/config/plugins/spec-adversary
```

Root `plugin.json`, install-by-path, the `~/.gemini/config/plugins/` target and
the unauthenticated `plugin list` all hold. `spec-adversary` will install for
attendees.

### Auth is identical on Linux

Same hosted redirect to `https://antigravity.google/oauth-callback`, same
paste-the-code prompt, same 60-second cap. Cloud Shell needs no special
handling.

### Footprint is larger than on macOS

| Measure | Cloud Shell | macOS |
| :--- | :--- | :--- |
| Binary | 197 MB | 169 MB |
| RSS at rest | **161 MB** | 88 MB |
| `~/.gemini` on disk | **545 MB**, 562 MB after update + login | — |

**`~/.gemini` at 545 MB is the number that matters.** A persistent Cloud Shell
home is **4.8 GB** (3.0 GB free when measured), so Antigravity's config
directory is roughly a third of what was already used. An attendee close to
their home quota can be pushed over it by this alone.

Ephemeral sessions are not affected in the same way: their scratch disk
reported **119 GB with 53 GB free**. So the constrained case is the
*persistent* session, which is the opposite of what one would guess.

## Gotchas

- **`agy plugin validate` is shallow.** It confirms `plugin.json` and counts
  component files. It does **not** parse SKILL.md frontmatter — a skill with no
  frontmatter at all, or a `name` that disagrees with its directory, still
  reports `✔ skills: 1 processed`. Do not use `validate` as the acceptance gate
  for LAB-06.
- **`plugin install` copies; it does not link.** Installed trees land in
  `~/.gemini/config/plugins/<name>/` as real directories. Editing the source
  after install changes nothing until reinstall. The skill dev loop is
  edit → `uninstall` → `install`.
- **Config lives under `~/.gemini/`**, not `~/.antigravity/`. Nothing is
  created until first login.
- **`agy plugin list` works unauthenticated and emits JSON.** LAB-04's preflight
  can verify the plugin loaded without forcing a login first.
- The agent-guidance filename for Antigravity CLI is **`GEMINI.md`**
  (`CLAUDE.md` and `AGENTS.md` are the other two the toolchain recognises).

## Outstanding

- RSS under load. At rest it is 88 MB on macOS and 161 MB on Cloud Shell.
- Marketplace version pinning: `install` accepts `plugin@marketplace`, but the
  pinning syntax was not established. Only matters if the skill ships via a
  marketplace rather than a git clone plus local-path install.
