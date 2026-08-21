#!/usr/bin/env bash
#
# Agentic SDLC workshop — preflight.
#
# Run this in your own Google Cloud project, before the session. It reports
# only to you; nothing is sent anywhere.
#
#   export AGENT_ENGINE_LOCATION=us-central1
#   export MODEL_LOCATION=global
#   bash scripts/preflight.sh
#
# Every check that fails prints the exact command that fixes it, and the run
# continues so you get the whole list in one pass. Safe to run twice.
#
#   --plan-only   check everything and show the Terraform plan, change nothing
#   --help        this text

set -uo pipefail

# Nothing here reads input, and several things it calls will ask for some --
# gcloud offers to enable an API, agents-cli setup picks an agent. Their output
# is redirected, so a prompt would hang with nothing on screen. Closed stdin
# turns that into an immediate failure with a message.
exec </dev/null

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TF_DIR="$REPO_ROOT/terraform"
MODEL="gemini-3.6-flash"
SECRET_ID="agentic-sdlc-deploy-key"
PLAN_ONLY=0

case "${1:-}" in
  --plan-only) PLAN_ONLY=1 ;;
  --help|-h)   sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
  "")          ;;
  *)           echo "unknown argument: $1 (try --help)" >&2; exit 2 ;;
esac

# --- reporting -------------------------------------------------------------
# Failures accumulate rather than exiting, so one run yields the whole list.
# FIXES is a newline-separated list; bash 3.2 has no associative arrays and
# macOS ships bash 3.2.
FAILED=0
FIXES=""
BLOCKERS=0

if [ -t 1 ]; then B=$(printf '\033[1m'); R=$(printf '\033[0m'); RED=$(printf '\033[31m'); GRN=$(printf '\033[32m'); YEL=$(printf '\033[33m')
else B=""; R=""; RED=""; GRN=""; YEL=""; fi

section() { printf '\n%s== %s ==%s\n' "$B" "$1" "$R"; }
ok()      { printf '  %sok%s    %s\n' "$GRN" "$R" "$1"; }
info()    { printf '  --    %s\n' "$1"; }
warn()    { printf '  %swarn%s  %s\n' "$YEL" "$R" "$1"; }
fail() {
  # fail "<what is wrong>" "<command that fixes it>"
  printf '  %sFAIL%s  %s\n' "$RED" "$R" "$1"
  FAILED=$((FAILED + 1))
  FIXES="${FIXES}
${B}$1${R}
    $2
"
}
blocker() { fail "$1" "$2"; BLOCKERS=$((BLOCKERS + 1)); }

report_and_exit() {
  if [ "$FAILED" -eq 0 ]; then
    section "ready"
    echo "  Everything checked out. Nothing to do until the session."
    exit 0
  fi
  section "$FAILED problem(s) — each with the command that fixes it"
  printf '%s\n' "$FIXES"
  echo "Fix these and run preflight again. It is safe to re-run."
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

# --plan-only must change nothing at all, locally or in the project. Every
# mutating step is guarded by this rather than by the terraform block alone.
would() {
  if [ "$PLAN_ONLY" -eq 1 ]; then printf '  --    would: %s\n' "$1"; return 1; fi
  return 0
}

# --- 1. locations ----------------------------------------------------------
# No defaults, deliberately. A guessed region builds a URL that resolves and
# points somewhere else, and sessions come back empty with nothing to explain it.
section "locations"

if [ -z "${AGENT_ENGINE_LOCATION:-}" ]; then
  blocker "AGENT_ENGINE_LOCATION is not set" 'export AGENT_ENGINE_LOCATION=us-central1'
else
  case "$AGENT_ENGINE_LOCATION" in
    global) blocker "AGENT_ENGINE_LOCATION is 'global', which is a model endpoint, not a region. Interpolated into a host it gives global-aiplatform.googleapis.com, which does not resolve." \
              'export AGENT_ENGINE_LOCATION=us-central1' ;;
    *-*[0-9]) ok "AGENT_ENGINE_LOCATION=$AGENT_ENGINE_LOCATION" ;;
    *) blocker "AGENT_ENGINE_LOCATION='$AGENT_ENGINE_LOCATION' is not a region" 'export AGENT_ENGINE_LOCATION=us-central1' ;;
  esac
fi

if [ -z "${MODEL_LOCATION:-}" ]; then
  blocker "MODEL_LOCATION is not set" 'export MODEL_LOCATION=global'
else
  ok "MODEL_LOCATION=$MODEL_LOCATION"
fi

if [ -n "${MODEL_LOCATION:-}" ] && [ "${MODEL_LOCATION:-}" = "${AGENT_ENGINE_LOCATION:-}" ]; then
  blocker "MODEL_LOCATION and AGENT_ENGINE_LOCATION are both '$MODEL_LOCATION'. They are independent: $MODEL is served only from 'global', while the engine runs in a region. Matching them returns a 404 that names the model and reads as a typo." \
    'export MODEL_LOCATION=global'
fi

# The model endpoint host differs by location, and getting this wrong is the
# single most common failure in this stack.
if [ "${MODEL_LOCATION:-}" = "global" ]; then
  MODEL_HOST="aiplatform.googleapis.com"
else
  MODEL_HOST="${MODEL_LOCATION:-unset}-aiplatform.googleapis.com"
fi

[ "$BLOCKERS" -gt 0 ] && report_and_exit

# --- 2. toolchain ----------------------------------------------------------
section "toolchain"

check_tool() { # name, install command, note
  if have "$1"; then ok "$1 — $(command -v "$1")"; else fail "$1 is not installed${3:+ ($3)}" "$2"; fi
}
check_tool gcloud    'https://cloud.google.com/sdk/docs/install'
check_tool terraform 'brew install terraform    # or https://developer.hashicorp.com/terraform/install'
check_tool uv        'curl -LsSf https://astral.sh/uv/install.sh | sh'
check_tool gh        'brew install gh    # or https://cli.github.com'
check_tool npx       'install Node.js — https://nodejs.org (Cloud Shell has it already)'
# The binary is agy. `antigravity` is the IDE cask, not this.
check_tool agy       'brew install --cask antigravity-cli    # the command is agy, not antigravity'

# Being on PATH is not the same as being installed. Cloud Shell ships a stub
# that prints install instructions and exits 0, so every terraform command
# "succeeds" while doing nothing -- init reports ok and the apply changes
# nothing. Reporting a version is the thing only a real binary can do.
if have terraform; then
  TFV=$(terraform version -json 2>/dev/null | sed -n 's/.*"terraform_version": *"\([^"]*\)".*/\1/p' | head -1)
  if [ -n "$TFV" ]; then
    ok "terraform $TFV (the config needs >= 1.9.0 for cross-variable validation)"
  else
    fail "terraform is on PATH but does not report a version, so it is a stub rather than the real binary. Cloud Shell ships one of these." \
      'see the Install terraform step of the setup guide, or https://developer.hashicorp.com/terraform/install'
  fi
fi

# --- 3. reachability -------------------------------------------------------
# `agents-cli setup` shells out to `npx -y skills add <github url> -g`, so it
# needs npm AND github before this project's own resources matter at all. On a
# restricted network this is what fails, a long way from anything saying so.
section "network reachability"

reachable() { curl -sS -o /dev/null --max-time 15 -w '%{http_code}' "$1" 2>/dev/null; }

CODE=$(reachable https://registry.npmjs.org/)
case "$CODE" in
  2*|3*) ok "registry.npmjs.org reachable" ;;
  *)     fail "cannot reach registry.npmjs.org (got '${CODE:-no response}'). agents-cli setup installs skills through npx and will fail here." \
           'Check your proxy/VPN, or ask your network team to allow registry.npmjs.org' ;;
esac

CODE=$(reachable https://github.com)
case "$CODE" in
  2*|3*) ok "github.com reachable over HTTPS" ;;
  *)     fail "cannot reach github.com (got '${CODE:-no response}')" \
           'Check your proxy/VPN, or ask your network team to allow github.com' ;;
esac

# --- 4. google cloud: account, project, billing -----------------------------
# Billing first: it is a prerequisite of the Agent Platform APIs, and its
# absence surfaces later as 403 BILLING_DISABLED from an unrelated-looking call.
section "google cloud"

if have gcloud; then
  ACCOUNT=$(gcloud config get-value account 2>/dev/null)
  if [ -z "$ACCOUNT" ] || [ "$ACCOUNT" = "(unset)" ]; then
    blocker "gcloud is not authenticated" 'gcloud auth login'
  else
    ok "account: $ACCOUNT"
  fi

  PROJECT=$(gcloud config get-value project 2>/dev/null)
  if [ -z "$PROJECT" ] || [ "$PROJECT" = "(unset)" ]; then
    blocker "no active gcloud project" 'gcloud config set project YOUR_PROJECT_ID'
  else
    ok "project: $PROJECT"
  fi

  if [ -n "${PROJECT:-}" ] && [ "$PROJECT" != "(unset)" ]; then
    PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)' 2>/dev/null)
    if [ -z "$PROJECT_NUMBER" ]; then
      blocker "cannot read project '$PROJECT' — wrong id, or your account has no access to it" \
        "gcloud projects describe $PROJECT"
    else
      ok "project number: $PROJECT_NUMBER"
      BILLED=$(gcloud beta billing projects describe "$PROJECT" --format='value(billingEnabled)' 2>/dev/null)
      if [ "$BILLED" = "True" ]; then
        ok "billing is linked"
      else
        blocker "billing is not linked to $PROJECT. The Agent Platform APIs refuse with 403 BILLING_DISABLED, which does not mention billing in the call that fails." \
          "gcloud beta billing projects link $PROJECT --billing-account=YOUR_BILLING_ACCOUNT_ID"
      fi
    fi
  fi
fi

[ "$BLOCKERS" -gt 0 ] && report_and_exit

# --- 5. credentials for Terraform ------------------------------------------
# Terraform resolves ADC through the Go auth library, which reads
# GOOGLE_APPLICATION_CREDENTIALS and then a hardcoded
# ~/.config/gcloud/application_default_credentials.json. It does NOT honour
# CLOUDSDK_CONFIG, so a second gcloud configuration moves every gcloud command
# here and leaves Terraform running as a different account. It surfaces as
# "does not have permission to access Project X or it may not exist", which
# reads as a wrong project id rather than a wrong identity.
section "application default credentials"

ADC_PATH="${GOOGLE_APPLICATION_CREDENTIALS:-${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}/application_default_credentials.json}"
if [ -r "$ADC_PATH" ]; then
  ok "ADC file: $ADC_PATH"
  export GOOGLE_APPLICATION_CREDENTIALS="$ADC_PATH"
  if [ -n "${CLOUDSDK_CONFIG:-}" ]; then
    info "CLOUDSDK_CONFIG is set; exporting GOOGLE_APPLICATION_CREDENTIALS so Terraform uses the same account"
  fi
else
  blocker "no application default credentials at $ADC_PATH. Terraform needs these, and they are separate from 'gcloud auth login'." \
    'gcloud auth application-default login'
fi

[ "$BLOCKERS" -gt 0 ] && report_and_exit

# --- 6. APIs ---------------------------------------------------------------
# terraform/locals.tf owns the canonical list; this is a courtesy that produces
# a better error than a mid-apply failure.
section "apis"

REQUIRED_APIS=$(sed -n '/required_services = \[/,/\]/p' "$TF_DIR/locals.tf" | sed -n 's/.*"\([a-z0-9.]*\.googleapis\.com\)".*/\1/p')
ENABLED=$(gcloud services list --enabled --project="$PROJECT" --format='value(config.name)' 2>/dev/null)
MISSING=""
for api in $REQUIRED_APIS; do
  case "
$ENABLED
" in
    *"
$api
"*) ;;
    *) MISSING="$MISSING $api" ;;
  esac
done
if [ -z "$MISSING" ]; then
  ok "all $(echo "$REQUIRED_APIS" | wc -w | tr -d ' ') required APIs enabled"
else
  # Not fatal: terraform enables them. Enabling here first makes the apply faster
  # and the failure legible if the account cannot enable services.
  warn "not yet enabled:$MISSING"
  info "Terraform will enable these; run the command below first if the apply fails on permissions"
  info "gcloud services enable$MISSING --project=$PROJECT"
fi

# --- 7. project parent, for the agent trust domain -------------------------
# The agent's principal lives in a workload identity pool named after the
# project's parent. Terraform derives it, and refuses when it cannot — a
# folder-parented project reports no org_id. Detect that here and pass the
# value in, rather than letting the apply fail with something cryptic.
section "agent trust domain"

PARENT_TYPE=$(gcloud projects describe "$PROJECT" --format='value(parent.type)' 2>/dev/null)
PARENT_ID=$(gcloud projects describe "$PROJECT" --format='value(parent.id)' 2>/dev/null)
TRUST_DOMAIN_ARG=""

case "$PARENT_TYPE" in
  organization)
    ok "project is under organization $PARENT_ID — Terraform derives the trust domain"
    ;;
  folder)
    ORG_ID=$(gcloud projects get-ancestors "$PROJECT" --format='value(id,type)' 2>/dev/null | awk '$2=="organization"{print $1}')
    if [ -n "$ORG_ID" ]; then
      TRUST_DOMAIN_ARG="-var=agent_trust_domain=agents.global.org-${ORG_ID}.system.id.goog"
      ok "project is in a folder under organization $ORG_ID — passing the trust domain explicitly"
    else
      fail "project is in a folder and its organization could not be resolved. Terraform cannot derive the agent trust domain, and guessing is worse than failing: a binding to the wrong trust domain is accepted and grants nothing." \
        "gcloud projects get-ancestors $PROJECT    # then re-run with:
    export AGENT_TRUST_DOMAIN=agents.global.org-<ORG_ID>.system.id.goog"
    fi
    ;;
  *)
    # No organization. The pool is named after the project instead. This path
    # is not yet verified against a real no-org project.
    warn "project has no organization — the trust domain becomes agents.global.project-${PROJECT_NUMBER}.system.id.goog"
    warn "this path is UNVERIFIED; if the agent later cannot read the deploy key, this is the first thing to suspect"
    ;;
esac
# An explicit override always wins.
[ -n "${AGENT_TRUST_DOMAIN:-}" ] && TRUST_DOMAIN_ARG="-var=agent_trust_domain=${AGENT_TRUST_DOMAIN}"

# --- 8. the model, by a real call ------------------------------------------
# A catalog entry describes the model, not your access to it. Only a real
# generateContent call settles availability.
section "model access"

TOKEN=$(gcloud auth print-access-token 2>/dev/null)
if [ -z "$TOKEN" ]; then
  fail "could not mint an access token" 'gcloud auth login'
else
  MODEL_URL="https://${MODEL_HOST}/v1/projects/${PROJECT}/locations/${MODEL_LOCATION}/publishers/google/models/${MODEL}:generateContent"
  BODY=$(curl -sS --max-time 60 -o /tmp/preflight-model.json -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
    "$MODEL_URL" -d '{"contents":[{"role":"user","parts":[{"text":"reply with the single word: ready"}]}]}' 2>/dev/null)
  case "$BODY" in
    200) ok "$MODEL answers from $MODEL_LOCATION" ;;
    404) fail "$MODEL returned 404 from '$MODEL_LOCATION'. The Gemini 3 family is served only from 'global'; a regional endpoint 404s with a message that names the model and reads like a typo." \
           'export MODEL_LOCATION=global' ;;
    403) fail "403 calling $MODEL. Usually the API is not enabled, or billing is not linked." \
           "gcloud services enable aiplatform.googleapis.com --project=$PROJECT" ;;
    *)   fail "unexpected response calling $MODEL (http ${BODY:-none}): $(head -c 200 /tmp/preflight-model.json 2>/dev/null)" \
           "curl -H \"Authorization: Bearer \$(gcloud auth print-access-token)\" $MODEL_URL" ;;
  esac
  rm -f /tmp/preflight-model.json
fi

# --- 9. github ------------------------------------------------------------
section "github"

if have gh; then
  if GH_STATUS=$(gh auth status 2>&1); then
    GH_USER=$(printf '%s\n' "$GH_STATUS" | sed -n 's/.*\(account\|as\) \([A-Za-z0-9._-]*\).*/\2/p' | head -1)
    ok "gh is authenticated${GH_USER:+ as $GH_USER}"
  else
    fail "gh is not authenticated. You fork the lab repo and add a deploy key on the day, both through gh." 'gh auth login'
  fi
fi

# --- 10. agents-cli and the ADK skills -------------------------------------
# Without these the coding agent cannot scaffold, evaluate or deploy, which is
# most of the lab.
section "agents-cli and ADK skills"

if have uv; then
  if have agents-cli; then
    ok "agents-cli — $(agents-cli --version 2>/dev/null | head -1)"
  elif would "uv tool install google-agents-cli"; then
    warn "agents-cli not installed; installing"
    uv tool install google-agents-cli >/dev/null 2>&1 \
      && ok "agents-cli installed" \
      || fail "could not install agents-cli" 'uv tool install google-agents-cli'
  else
    warn "agents-cli is not installed"
  fi

  if have agents-cli; then
    SKILL_DIRS="$HOME/.gemini/config/skills $HOME/.gemini/antigravity-cli/skills"
    FOUND=""
    for d in $SKILL_DIRS; do
      [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ] && FOUND="$d"
    done
    if [ -z "$FOUND" ] && would "agents-cli setup  # installs the ADK skills for Antigravity"; then
      info "running agents-cli setup (reaches npm and github)"
      agents-cli setup >/dev/null 2>&1
      for d in $SKILL_DIRS; do
        [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ] && FOUND="$d"
      done
    fi
    if [ -n "$FOUND" ]; then
      ok "ADK skills present in $FOUND"
    elif [ "$PLAN_ONLY" -eq 1 ]; then
      warn "ADK skills are not installed for Antigravity yet; a real run installs them"
    else
      fail "ADK skills did not land in ~/.gemini. agents-cli setup shells out to 'npx -y skills add <github url> -g', so this usually means npm or github was unreachable. Note it installs into whichever coding agent it detects — if you also use Claude Code, check ~/.claude/skills before assuming it failed." \
        'agents-cli setup --agent antigravity'
    fi
  fi
fi

# --- 11. the spec-adversary plugin -----------------------------------------
# `agy plugin list` works unauthenticated, so this check does not require the
# attendee to have logged in to agy yet.
section "spec-adversary plugin"

if have agy; then
  if agy plugin list 2>/dev/null | grep -q 'spec-adversary'; then
    ok "spec-adversary is installed"
  elif would "cd $REPO_ROOT && agy plugin install ."; then
    info "installing spec-adversary from this clone"
    ( cd "$REPO_ROOT" && agy plugin install . >/dev/null 2>&1 )
    if agy plugin list 2>/dev/null | grep -q 'spec-adversary'; then
      ok "spec-adversary installed"
    else
      fail "spec-adversary did not install from $REPO_ROOT" \
        "cd $REPO_ROOT && agy plugin install ."
    fi
  else
    warn "spec-adversary is not installed"
  fi
  # `agy plugin validate` never reads SKILL.md frontmatter, so a broken skill
  # passes it. It is not used as a gate here.
fi

# --- 12. terraform ---------------------------------------------------------
section "terraform"

TF_VARS="-var=project_id=$PROJECT -var=agent_engine_location=$AGENT_ENGINE_LOCATION -var=model_location=$MODEL_LOCATION"
[ -n "$TRUST_DOMAIN_ARG" ] && TF_VARS="$TF_VARS $TRUST_DOMAIN_ARG"

if ! have terraform; then
  fail "terraform is required to provision the project" 'brew install terraform'
  report_and_exit
fi

if ! terraform -chdir="$TF_DIR" init -input=false >/dev/null 2>&1; then
  fail "terraform init failed" "terraform -chdir=$TF_DIR init"
  report_and_exit
fi
ok "terraform initialised"

# Idempotency across clones. Preflight may run in a different clone from the
# one that ran it last — clicking the Open in Cloud Shell link again produces
# workshop-agentic-sdlc-0, -1, ... rather than updating the first — and the
# state file is local and gitignored. A secret that exists but is absent from
# state fails the apply with 409 already exists, so adopt it instead.
if ! terraform -chdir="$TF_DIR" state list 2>/dev/null | grep -q 'google_secret_manager_secret.deploy_key'; then
  if gcloud secrets describe "$SECRET_ID" --project="$PROJECT" >/dev/null 2>&1 \
     && would "terraform import google_secret_manager_secret.deploy_key"; then
    info "secret $SECRET_ID exists but is not in this clone's state — importing"
    if terraform -chdir="$TF_DIR" import $TF_VARS \
        google_secret_manager_secret.deploy_key "projects/$PROJECT/secrets/$SECRET_ID" >/dev/null 2>&1; then
      ok "imported the existing secret"
    else
      fail "could not import the existing secret $SECRET_ID; the apply would fail with 409 already exists" \
        "terraform -chdir=$TF_DIR import $TF_VARS google_secret_manager_secret.deploy_key projects/$PROJECT/secrets/$SECRET_ID"
      report_and_exit
    fi
  fi
fi

if [ "$PLAN_ONLY" -eq 1 ]; then
  terraform -chdir="$TF_DIR" plan -input=false $TF_VARS
  info "--plan-only: nothing was changed"
  report_and_exit
fi

if terraform -chdir="$TF_DIR" apply -input=false -auto-approve $TF_VARS >/tmp/preflight-tf.log 2>&1; then
  ok "terraform applied"
  info "$(grep -E '^(Apply complete|No changes)' /tmp/preflight-tf.log | head -1)"
  SECRET_OUT=$(terraform -chdir="$TF_DIR" output -raw deploy_key_secret_id 2>/dev/null)
  PSET=$(terraform -chdir="$TF_DIR" output -raw agent_principal_set 2>/dev/null)
  [ -n "$SECRET_OUT" ] && info "deploy key secret: $SECRET_OUT (empty until the day)"
  [ -n "$PSET" ] && info "agent principal:   $PSET"
else
  fail "terraform apply failed — see /tmp/preflight-tf.log
$(tail -15 /tmp/preflight-tf.log | sed 's/^/      /')" \
    "terraform -chdir=$TF_DIR apply $TF_VARS"
fi

report_and_exit
