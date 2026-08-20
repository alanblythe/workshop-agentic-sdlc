# LAB-03 — `claat` findings

Verified 2026-08-20 on macOS 15 (arm64), Go 1.26.5, against `claat` built from
`github.com/googlecodelabs/tools/claat@latest`, which resolved to
**`v0.0.0-20240220115335-873fe39d02dc`** — a Feb 2024 pseudo-version. That is
the newest thing the module proxy offers.

The Pages-hosting checkbox is **not** covered here; it needs a repo decision.

## Install

There is no Homebrew formula:

```
Error: No available formula with the name "claat". Did you mean clamav, lavat or clac?
```

`go install` is the install path, and it is fast — 8 seconds cold:

```shell
go install github.com/googlecodelabs/tools/claat@latest
```

The binary lands at `$(go env GOPATH)/bin/claat` (15 MB) and needs
`$(go env GOPATH)/bin` on `PATH`. **Go is therefore a prerequisite for anyone
who builds the guide**, though not for attendees, who only read the output.

`claat version` prints an empty line and exits 0. The version string is
injected by `-ldflags` in the project's own release build, so a `go install`
binary cannot report what it is. Pin by module pseudo-version instead.

## Export

```shell
claat export probe.lab.md
```

Output on success is one line per source, `ok\t<id>`. It writes a directory
named for the metadata `id`, in the current directory unless `-o` is given:

```
claat-probe-b/index.html
claat-probe-b/codelab.json
```

The `.lab.md` extension is accepted — `claat` chooses the Markdown parser for
anything that is not a Google Doc ID, so the double extension is inert.

`claat update` re-exports every directory under the current one that holds a
`codelab.json`, reusing the flags recorded in it. That is the CI shape for
LAB-16.

## Durations sum — but not from the house template's syntax

**Confirmed summing, with a caveat that changes every duration tag in the
guide.**

The step parser splits `Duration:` on `:` and right-aligns the parts against
`[hour, minute, second]`. So:

| Written | Parsed as | Rendered |
|---|---|---|
| `Duration: 7` | 7 minutes | 7 |
| `Duration: 0:07` | 0 min **7 seconds** | **1** |
| `Duration: 0:07:00` | 0h 7m 0s | 7 |

Any fractional minute rounds **up**, so `0:07` becomes one minute rather than
zero — a silent, plausible-looking wrong answer, not an error.

Two identical five-step codelabs differing only in duration syntax:

```
claat-probe-a  (Duration: 0:02 / 0:07 / 0:12 / 0:04 / 0:01)  "duration": 5
claat-probe-b  (Duration: 0:02:00 / … / 0:01:00)             "duration": 26
```

2 + 7 + 12 + 4 + 1 = 26. Loaded in a browser off a local static server,
probe-b's navbar reads **`26 mins remaining`** and each
`<google-codelab-step>` carries the right per-step `duration` attribute. Every
step's tag counts, including step 1 and the final step.

**The house template's `Duration: 0:05` means five seconds to this compiler.**
Use `Duration: 5` or `Duration: 0:05:00`. LAB-04 wants tags summing to ~59
minutes; written the house way it would publish as 12.

## The house template is DevSite CLaaT, and OSS `claat` is not

These are two different compilers. Three of the house template's rules are
rejected or silently ignored by the binary that will actually build this guide.

### YAML frontmatter is not accepted

A `---`-fenced block fails outright:

```
err	probe.lab.md invalid metadata format, missing at least id: map[duration:0:02]
```

`claat` reads metadata from the **first paragraph of the document** — bare
`key: value` lines above the `#` title, no fences:

```
summary: What the reader builds
id: agentic-sdlc-lab
categories: cloud,agents
environments: Web
status: Draft
authors: Alan Blythe
feedback link: https://github.com/…/issues

# Title
```

Recognised keys, and only these: `authors`, `summary`, `id`, `categories`,
`environments`, `status`, `feedback_link`, `analytics_account`,
`analytics_ga4_account`, `tags`, `source`, `duration`. Keys are snake-cased
before matching, so `feedback link` with a space works.

`description`, `keywords`, `layout`, `project` and `book` — five of the house
template's eight fields — are **dropped without warning** unless named in
`-pass_metadata`. In particular the summary comes from `summary`, not
`description`; with `description` the exported `"summary"` is `""`.

### `Positive` / `Negative` callouts do not render

The definition-list syntax needs a `<dt>`, and `claat` builds its Markdown
tree with goldmark configured for only the Typographer and Table extensions —
no definition lists. `isInfobox` can therefore never fire from a Markdown
source. It is dead code for this input format.

```markdown
Positive
: **Tip:** …
```

renders as the literal paragraph `Positive : Tip: …`. No error, no styling.

The syntax that works is a blockquote whose first line is `aside positive` or
`aside negative`:

```markdown
> aside positive
>
> This is a tip.

> aside negative
>
> This is a warning.
```

Confirmed in a browser: green left-rule tip box and amber warning box,
`<aside class="special">` and `<aside class="warning">`.

### Buttons must be one line

`isButton` matches an actual `<button>` element, which raw HTML passes
through. It must be on a single line, or the Markdown link inside is never
parsed:

```markdown
<button>[Open in Cloud Shell](https://…)</button>
```

renders `<paper-button class="colored" raised>`. Split across three lines it
emits the literal text `[Open in Cloud Shell](https://…)`. The house
template's plain `[Label](url)` is a plain link; so is `[**Label**](url)`.

## Numbered step headings double-number

`codelab-elements.js` prefixes the step index to the step title itself. The
drawer uses the label verbatim and draws its own numbered circle. So the house
rule `## 1. Before you begin` produces:

- step title: **`1. 1. Before you begin`**
- drawer entry: circle `1` + `1. Before you begin`

Dropping the number from the heading gives the right result in both places —
title `1. Before you begin`, drawer circle `1` + `Before you begin`. **Do not
number `##` headings.**

## Hosting shape

`-f html` (the default) emits a single `index.html` per codelab that pulls four
scripts and one stylesheet from `https://storage.googleapis.com/claat-public/`
plus Google Fonts and `//support.google.com/inapp/api.js`. All reachable (200)
from here. Nothing is vendored, so a restricted customer network that blocks
`storage.googleapis.com` gets an unstyled, non-interactive page — the drawer,
the progress bar and the timer are all in `codelab-elements.js`. Worth adding
to LAB-20's restricted-network run.

`-f offline` is **not** a usable escape hatch. It splits into `step-N.html`
and, with the default `-prefix`, concatenates without a separator:

```html
<link rel="stylesheet" href="https://storage.googleapis.comstyles/codelab.css">
<script src="https://storage.googleapis.comscripts/codelab.js"></script>
```

`-prefix ./` fixes the paths, but `claat` never emits `styles/codelab.css` or
`scripts/codelab.js` at all. Truly self-contained hosting means vendoring the
`claat-public` assets and passing `-prefix` yourself.

**`-ga` defaults to `UA-49880327-14`** — Google's own Codelabs property — and
it is written into every exported page as
`<google-codelab-analytics gaid="UA-49880327-14">`. Pass `-ga ""` or a real
property. Do not ship the default.

## Cloud Shell deep link — documented form established, house form unproven

The two forms in the issue are not equivalent, and only one is documented.

**Use this:**

```
https://shell.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/ORG/REPO
```

How that was established: Google's *Open in Cloud Shell* reference
(`docs.cloud.google.com/shell/docs/open-in-cloud-shell`, page footer *Last
updated 2026-08-11*) was fetched and grepped. It names `shell.cloud.google.com`
as the base URL, `cloudshell_git_repo` as the one **required** parameter, and
gives exactly one example, on `/cloudshell/editor`. The optional parameters are
`cloudshell_git_branch`, `cloudshell_image`, `cloudshell_open_in_editor`,
`cloudshell_print`, `cloudshell_tutorial`, `cloudshell_workspace`, `ephemeral`
and `show`. A bare `git_repo` occurs **zero** times on that page.

The house template's `/cloudshell/open?git_repo=…` is the pre-2019 form. It is
**not deprecated in writing, and it is still in production**: the currently
published codelab `cloud-webapp-hosting-gce` links to

```
https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/googlecodelabs/monolith-to-microservices.git&page=editor
```

**Neither form was exercised end to end.** Unauthenticated `curl` cannot
separate them — all four variants tried (`shell.` and `console.` hosts, `open`
and `editor` paths, both parameter spellings) return an identical `302` to
`accounts.google.com/ServiceLogin`, and `console.cloud.google.com` proxies the
query string to `shell.cloud.google.com` **verbatim**, rewriting neither the
path nor the parameter name — so the server reveals nothing. Parameter handling
is client-side, behind the login. Confirming it needs one signed-in click, and
that would have started a Cloud Shell VM on the user's account, which was out
of scope here.

So: the recommendation rests on documentary evidence, not a click. It is the
form Google documents today; the legacy form is undocumented and survives only
by inertia. **Take the documented one, and click it once during LAB-20.**

### The finding that actually matters

From the same reference, on `cloudshell_git_repo`:

> Only allow listed repos owned by Google will open in the default Cloud Shell
> environment and have access to the user's credentials. All other repos will
> use a temporary Cloud Shell environment without access to the user's
> credentials.

An attendee's fork is not a Google-owned repo. Clicking **Open in Cloud Shell**
therefore drops them into an **ephemeral** Cloud Shell with a **scratch home
directory** and **no credentials** — which is the opposite of what LAB-01
assumed when it kept Cloud Shell as the workstation on the strength of `agy`'s
pasted-code auth path. In an ephemeral session the 169 MB `agy` install does
not persist, and `gcloud` is not pre-authorized.

This is doc-sourced, not measured. It is the single highest-value thing to
check in the first dry run, because if it holds, step 2 of the codelab cannot
be an *Open in Cloud Shell* button — it has to be "open Cloud Shell, then
`git clone`", which keeps the persistent home directory.

## Gotchas

- **Content above the first `##` is discarded.** The parser ignores everything
  between the `#` title and the first step boundary. An introduction written
  there vanishes silently.
- **`claat export` overwrites without asking** and `claat update` deletes
  assets it thinks are unused, including the whole directory if `id` changed.
  Never point `-o` at a directory holding anything hand-written.
- **`claat update` recurses.** Run from the repo root it will find and
  re-export every `codelab.json` beneath, not just the one you meant.
- The default `cloudshell_git_branch` is documented as **`master`**. Untested
  against a `main`-only repo; pass `cloudshell_git_branch=main` explicitly.
- The parser accepts unknown metadata keys silently, accepts a mis-scaled
  `Duration:` silently, and renders a wrong callout silently. **Nothing in this
  toolchain fails loudly.** LAB-16's acceptance has to be a rendered page
  someone looks at, not a zero exit code.

## Outstanding

- One signed-in click on each Cloud Shell URL form, to settle `git_repo` vs
  `cloudshell_git_repo` by observation.
- Whether an attendee's fork really lands in an ephemeral, credential-less
  Cloud Shell. Decides the shape of codelab step 2.
- GitHub Pages hosting — deliberately not attempted; blocked on the repo
  decision.

## Open in Cloud Shell is unusable for this lab

![The Open in Cloud Shell dialog for a non-Google repo](../images/cloud-shell-ephemeral-warning.png)

Confirmed live against `github.com/octocat/Hello-World`. The dialog appears
before anything runs:

> This repo is not officially maintained by Google and is considered untrusted
> by default.
>
> **This session will run in Ephemeral mode and all files will be deleted on
> session end.**

The same URL against a Google-owned repo
(`GoogleCloudPlatform/python-docs-samples`) says only *"This repo is officially
maintained by Google."* — no ephemeral warning and no checkbox. So the
behaviour is governed by the Google-ownership allow list, not by the URL form.

**The `Trust repo` checkbox is optional and does not gate the clone** —
`Confirm` proceeds with it unticked. What ticking it changes was not tested.
Note the dialog states the ephemeral behaviour flatly, not as a consequence of
leaving the box unticked, so nothing here suggests it is an opt-out. Either
way the button cannot be relied on: a lab step whose environment depends on an
attendee noticing an unexplained checkbox is not a lab step.

An attendee's fork is never Google-owned, so the button would hand them a
scratch `$HOME` deleted at session end, with no credentials. The lab installs
`agy` (169 MB) and authenticates — both would be discarded.

**Decision: do not ship an Open in Cloud Shell button.** Cloud Shell itself is
unaffected and remains the workstation; only the `cloudshell_git_repo` link is
withdrawn. Step 2 of the guide sends the attendee to plain Cloud Shell and has
them clone:

```
https://shell.cloud.google.com/
git clone https://github.com/OWNER/REPO && cd REPO
```

That keeps the default, persistent, credentialed environment.
