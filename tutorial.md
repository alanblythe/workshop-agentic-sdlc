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

## Directives the codelab format has no answer for

<walkthrough-tutorial-duration duration="1"></walkthrough-tutorial-duration>

Open a file directly in the editor:

<walkthrough-editor-open-file filePath="README.md">
Open README.md
</walkthrough-editor-open-file>

<walkthrough-footnote>
A footnote renders in a muted style at the bottom of the step.
</walkthrough-footnote>

## Done

<walkthrough-conclusion-trophy></walkthrough-conclusion-trophy>

If you are reading this in a panel beside a terminal, the mechanism works.
