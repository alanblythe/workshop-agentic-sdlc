# Cloud Shell tutorial format probe

<walkthrough-tutorial-duration duration="3"></walkthrough-tutorial-duration>

A throwaway tutorial used to establish what the Cloud Shell side panel renders,
and how its format differs from the CLaaT codelab the lab guide is written in.

It is not the lab. See `docs/verification/lab-03-claat.md` for what it settled.

## Headings become steps

<walkthrough-tutorial-duration duration="1"></walkthrough-tutorial-duration>

A level-1 heading is the title, a level-2 heading is a **step**, and a level-3
heading is an item inside it. The panel shows one step at a time with Next and
Back, which is the structural difference from a codelab page.

### An item inside the step

Items do not get their own panel; they render inline.

## Code blocks and the project picker

<walkthrough-tutorial-duration duration="1"></walkthrough-tutorial-duration>

A fenced block gets a copy-to-terminal control:

```bash
echo "the panel can push this straight into the shell"
```

Pick a project, which the real guide would need before anything touches GCP:

<walkthrough-project-setup></walkthrough-project-setup>

The picker only sets a **tutorial variable**. It does not touch the shell, so
a step has to apply it — this is the part a guide is easy to ship without:

```bash
export GOOGLE_CLOUD_PROJECT="<walkthrough-project-id/>"
gcloud config set project "$GOOGLE_CLOUD_PROJECT"
gcloud config get-value project
```

In an ephemeral session the shell also starts with no credentials, so this is
needed before anything can call an API:

```bash
gcloud auth login --update-adc
```

## Directives the codelab format has no answer for

<walkthrough-tutorial-duration duration="1"></walkthrough-tutorial-duration>

Open a file directly in the editor:

<walkthrough-editor-open-file filePath="README.md">
Open README.md
</walkthrough-editor-open-file>

<walkthrough-footnote>
A footnote renders in a muted style at the bottom of the step.
</walkthrough-footnote>

## Get agy onto the latest version

<walkthrough-tutorial-duration duration="2"></walkthrough-tutorial-duration>

The image ships `agy` at `/usr/bin/agy`, and the version varies by session —
1.1.9 and 1.1.13 have both been seen. The lab runs on the current release
instead, so everyone is on the same one.

> aside negative
> This is a **every-session** step. `agy update` replaces the binary in
> `/usr/bin`, which is on the VM rather than the persistent disk, so it is
> discarded whenever Cloud Shell recycles. If you reconnect later, run it
> again — and if anything misbehaves afterwards, check `agy --version` first.

Record what you start with:

```bash
agy --version && command -v agy
```

Now update. `agy` has its own updater:

```bash
agy update
```

If that fails on permissions, `/usr/bin` needs root — Cloud Shell grants
passwordless sudo:

```bash
sudo agy update
```

Check what you ended up with, and **where**:

```bash
agy --version
command -v agy
ls -la ~/.local/bin/agy 2>/dev/null || echo "not in ~/.local/bin"
```

<walkthrough-footnote>
Where it lands is the thing to watch. Cloud Shell persists only $HOME — the
rest of the VM is rebuilt — so an update written into /usr/bin is gone next
session, while one written under ~/.local/bin survives. If the updater writes
to /usr/bin, the lab needs this step every time rather than once.
</walkthrough-footnote>

## Authenticate agy

<walkthrough-tutorial-duration duration="3"></walkthrough-tutorial-duration>

**`agy` has its own login, separate from `gcloud`.** Authenticating gcloud and
ADC does nothing for `agy` — it holds its own OAuth grant with its own scopes
(`cloud-platform`, `aicode`, `cclog`, `experimentsandconfigs`). Two logins, not
one. There is no `agy login` subcommand; authentication happens on first use.

**Maximise the terminal panel first.** The login prints a very long URL, and a
narrow terminal wraps it across six or more lines, which makes it painful to
select cleanly. A wide terminal wraps it less.

> aside negative
> Use plain `agy`, not `agy -p`. Print mode caps the wait at 60 seconds and
> then fails with `authentication interrupted`. The interactive prompt has no
> timeout — it waits at an input field for as long as you need.

```bash
agy
```

You will get a prompt reading *"Open the URL below in your browser"*, then
*"After authenticating, copy the code displayed in the browser and paste it
below"*, with an `authorization code...` field.

The URL is emitted as a terminal hyperlink, so **try clicking it first** —
that avoids selecting the wrapped text at all. If clicking does nothing,
select the whole URL across its wrapped lines and copy it.

Approve in the browser, copy the code it shows, paste it into the field, and
press Enter. The browser need not be on this machine: the redirect goes to a
hosted callback rather than a localhost listener, which is what makes this work
in Cloud Shell.

Then leave the session with `/quit` and confirm the grant took:

```bash
agy -p "Reply with exactly: authenticated"
```

<walkthrough-footnote>
Answering without a URL prompt means the grant is in place. It lives under
~/.gemini, so an ephemeral session loses it when the session ends and a
persistent one keeps it.
</walkthrough-footnote>

## Probe agy on Linux

<walkthrough-tutorial-duration duration="3"></walkthrough-tutorial-duration>

LAB-01 measured the `agy` install on macOS only. Cloud Shell is Linux, so the
install path, footprint and whether it survives a new session are all unknown
— and Cloud Shell is where attendees actually run.

First get the latest of this repo, since the probe script is new:

```bash
git pull --ff-only
```

Confirm `agy` is on the path here:

```bash
command -v agy && agy --version
```

If that prints nothing, `agy` is not installed in this session — say so
rather than installing it blind, because *how* it gets installed is one of
the things being measured.

Now run the probe. It is read-only apart from one plugin install that it
removes again, and every call is capped so an unauthenticated `agy` cannot
hang the terminal:

```bash
bash scripts/probe-agy.sh 2>&1 | tee /tmp/agy-probe.txt
```

Then hand back the output:

```bash
cat /tmp/agy-probe.txt
```

<walkthrough-footnote>
The probe answers: install path and owner, binary size, whether PATH survives
a new shell, where config lands, whether the plugin surface works
unauthenticated, the shape of the auth prompt, and memory at rest.
</walkthrough-footnote>

## Done

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

If you are reading this in a panel beside a terminal, the mechanism works.
