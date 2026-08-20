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

- RSS under load, for Cloud Shell sizing. Needs an interactive login.
- Marketplace version pinning: `install` accepts `plugin@marketplace`, but the
  pinning syntax was not established. Only matters if the skill ships via a
  marketplace rather than a git clone plus local-path install.
