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
