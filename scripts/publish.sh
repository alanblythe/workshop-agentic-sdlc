#!/usr/bin/env bash
#
# Render the guides and publish the codelab to docs/.
#
#   bash scripts/publish.sh
#
# The copy-button pass has to run after every export: `claat export` rewrites
# index.html wholesale, so anything added to the previous one is gone. Running
# the two steps separately is how the buttons quietly disappear.

set -euo pipefail
CLAAT="${CLAAT:-$HOME/go/bin/claat}"
command -v "$CLAAT" >/dev/null 2>&1 || { echo "claat not found at $CLAAT — set CLAAT=/path/to/claat" >&2; exit 1; }

npm run build --silent
"$CLAAT" export -o docs setup.lab.md
node scripts/add-copy-buttons.mjs docs/agentic-sdlc-setup/index.html
echo "published docs/agentic-sdlc-setup/"
