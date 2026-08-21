#!/usr/bin/env bash
# LAB-01 follow-up: what `agy` looks like on Linux / Cloud Shell.
# LAB-01 measured the macOS cask only. Everything here is read-only except one
# plugin install, which is uninstalled again at the end.
#
#   bash scripts/probe-agy.sh 2>&1 | tee /tmp/agy-probe.txt
set -uo pipefail

hr() { printf '\n== %s ==\n' "$1"; }

hr "identity"
uname -srm
[ -r /etc/os-release ] && . /etc/os-release && echo "$PRETTY_NAME"
echo "cloud shell: ${GOOGLE_CLOUD_SHELL:-no}"

hr "is agy present, and where"
if ! command -v agy >/dev/null 2>&1; then
  echo "agy NOT on PATH, nothing else here will work."
  echo "PATH=$PATH"
  exit 1
fi
AGY=$(command -v agy)
echo "which        : $AGY"
echo "resolves to  : $(readlink -f "$AGY")"
echo "size         : $(du -h "$(readlink -f "$AGY")" | cut -f1)"
echo "version      : $(timeout 30 agy --version </dev/null 2>&1 | head -1)"

hr "how it was installed"
# Whichever of these answers, that is the install path worth documenting.
command -v brew >/dev/null 2>&1 && echo "brew present: $(brew list --cask 2>/dev/null | grep -i anti || echo 'no antigravity cask')"
dpkg -S "$(readlink -f "$AGY")" 2>/dev/null || echo "not owned by dpkg"
grep -rhoE '(curl|wget|npm i(nstall)?|go install|brew install)[^|;&]*(antigravity|agy)[^|;&]*' \
  ~/.bash_history ~/.zsh_history 2>/dev/null | sort -u | head -5 || true

hr "does the binary survive a session (persistence)"
case "$(readlink -f "$AGY")" in
  "$HOME"/*) echo "under \$HOME, persists across Cloud Shell sessions" ;;
  *) echo "$(dirname "$(readlink -f "$AGY")") is on the VM, not the persistent disk."
     echo "Cloud Shell persists only \$HOME, so any update here is lost when the VM recycles." ;;
esac
grep -rn "antigravity\|/agy" ~/.bashrc ~/.profile ~/.bash_profile 2>/dev/null | head -3 \
  || echo "(no shell-profile PATH entry needed for a system path)"

hr "config root"
for d in ~/.gemini ~/.gemini/config ~/.gemini/config/plugins ~/.gemini/config/skills ~/.gemini/antigravity-cli/skills ~/.antigravity; do
  [ -e "$d" ] && echo "EXISTS  $d  ($(find "$d" -maxdepth 1 -mindepth 1 2>/dev/null | wc -l | tr -d ' ') entries)" || echo "absent  $d"
done
echo "disk used by ~/.gemini: $(du -sh ~/.gemini 2>/dev/null | cut -f1 || echo n/a)"

hr "plugin surface (works unauthenticated)"
timeout 30 agy plugin list </dev/null 2>&1 | head -20

hr "install this repo as a plugin, then remove it"
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
echo "installing from: $REPO_ROOT"
timeout 60 agy plugin install "$REPO_ROOT" </dev/null 2>&1 | head -8
echo "--- list after ---"
timeout 30 agy plugin list </dev/null 2>&1 | head -20
echo "--- where did it land ---"
find ~/.gemini -maxdepth 4 -name "agentic-sdlc" 2>/dev/null | head -3
echo "--- uninstalling ---"
timeout 60 agy plugin uninstall agentic-sdlc </dev/null 2>&1 | head -3

hr "auth state / prompt shape (12s cap, will not complete a login)"
timeout 12 agy -p "Reply with exactly: ok" </dev/null 2>&1 | head -20
echo "[exit ${PIPESTATUS[0]:-?}, a URL + paste prompt means unauthenticated; 'ok' means already authenticated]"

hr "memory at rest"
timeout 25 agy -p "Reply with exactly: ok" </dev/null >/dev/null 2>&1 &
BG=$!
sleep 6
ps -o rss=,comm= -C agy 2>/dev/null | awk '{printf "  %.0f MB  %s\n", $1/1024, $2}' | head -3 \
  || ps -eo rss,comm | grep -i '[a]gy' | awk '{printf "  %.0f MB  %s\n", $1/1024, $2}' | head -3
wait $BG 2>/dev/null

hr "disk headroom"
df -h "$HOME" | tail -1

hr "done"
echo "paste /tmp/agy-probe.txt back"
