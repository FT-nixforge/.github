#!/usr/bin/env bash
# create-project — scaffold a GitHub repo + GitHub Project v2 from a template
#
# Usage: create-project [OPTIONS]
#
# Options:
#   --template TYPE    Template: ft-nixpkgs-flake | nix-project
#   --name NAME        Repo / project name
#   --desc DESC        Short description
#   --org ORG          GitHub organisation [default: FT-nixforge]
#   --no-repo          Skip repo creation (project only)
#   --no-project       Skip project creation (repo only)
#   --dry-run, -n      Preview without making API calls
#   --verbose, -v      Extra output
#   --help, -h         This help text
#
# Dependencies: gh (GitHub CLI, authenticated), jq, gum (charm.sh/gum)
# Run: gh auth login   — if not yet authenticated

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
die()   { echo -e "${RED}error:${NC} $*" >&2; exit 1; }
info()  { echo -e "${BLUE}→${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
vecho() { $VERBOSE && echo -e "${BLUE}[v]${NC} $*" >&2 || true; }

# ── Script location (templates are siblings of this script) ──────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Deps ──────────────────────────────────────────────────────────────────────
for _dep in gh jq gum; do
  command -v "$_dep" &>/dev/null \
    || die "'$_dep' not found. Install it (e.g. nix shell nixpkgs#gh nixpkgs#jq nixpkgs#gum)."
done

# ── Args ──────────────────────────────────────────────────────────────────────
DRY_RUN=false; VERBOSE=false
CREATE_REPO=true; CREATE_PROJECT=true
OPT_TEMPLATE=""; OPT_NAME=""; OPT_DESC=""; OPT_ORG="FT-nixforge"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template)   shift; OPT_TEMPLATE="$1" ;;
    --name)       shift; OPT_NAME="$1" ;;
    --desc)       shift; OPT_DESC="$1" ;;
    --org)        shift; OPT_ORG="$1" ;;
    --no-repo)    CREATE_REPO=false ;;
    --no-project) CREATE_PROJECT=false ;;
    --dry-run|-n) DRY_RUN=true ;;
    --verbose|-v) VERBOSE=true ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | grep '^#' | sed 's/^# \?//'
      exit 0 ;;
    -*) die "Unknown option: $1" ;;
  esac
  shift
done

# ── Auth + org membership check ───────────────────────────────────────────────
CURRENT_USER="$(gh api user --jq '.login' 2>/dev/null)" \
  || die "Not authenticated with gh CLI. Run: gh auth login"

vecho "Authenticated as: $CURRENT_USER"

if ! $DRY_RUN; then
  if ! gh api "orgs/$OPT_ORG/members/$CURRENT_USER" --silent 2>/dev/null; then
    die "$(printf '@%s is not a member of the '\''%s'\'' organisation.\nOnly org members can create repos and projects here.' "$CURRENT_USER" "$OPT_ORG")"
  fi
  vecho "Org membership confirmed: $OPT_ORG"
fi

# ── Header ────────────────────────────────────────────────────────────────────
gum style \
  --foreground 212 --border-foreground 212 --border rounded \
  --align center --width 50 --margin "1 2" \
  "  FT-nixforge — Create Project  "

# ── Template selection ────────────────────────────────────────────────────────
if [[ -z "$OPT_TEMPLATE" ]]; then
  OPT_TEMPLATE="$(gum choose \
    --header "Select project template:" \
    "ft-nixpkgs-flake" \
    "nix-project")"
fi

TEMPLATE_DIR="$SCRIPT_DIR/$OPT_TEMPLATE"
[[ -d "$TEMPLATE_DIR" ]] \
  || die "Unknown template '$OPT_TEMPLATE'. Expected: ft-nixpkgs-flake | nix-project"

TEMPLATE_JSON="$TEMPLATE_DIR/project.json"
[[ -f "$TEMPLATE_JSON" ]] || die "project.json not found at: $TEMPLATE_JSON"

# ── Name ──────────────────────────────────────────────────────────────────────
if [[ -z "$OPT_NAME" ]]; then
  case "$OPT_TEMPLATE" in
    ft-nixpkgs-flake) PLACEHOLDER="ft-myflake" ;;
    nix-project)      PLACEHOLDER="my-nix-tool" ;;
  esac
  OPT_NAME="$(gum input \
    --placeholder "$PLACEHOLDER" \
    --prompt "Name › ")"
fi
[[ -n "$OPT_NAME" ]] || die "Name is required."
OPT_NAME="${OPT_NAME// /-}"

# ── Org (confirmed; allow override) ───────────────────────────────────────────
OPT_ORG="$(gum input \
  --placeholder "FT-nixforge" \
  --prompt "Organisation › " \
  --value "$OPT_ORG")"
[[ -n "$OPT_ORG" ]] || die "Organisation is required."

# ── Description ───────────────────────────────────────────────────────────────
if [[ -z "$OPT_DESC" ]]; then
  OPT_DESC="$(gum input \
    --placeholder "A short description" \
    --prompt "Description › ")"
fi

# ── Visibility ────────────────────────────────────────────────────────────────
REPO_VIS="$(jq -r '.repo.visibility // "public"' "$TEMPLATE_JSON")"
REPO_VIS="$(gum choose \
  --header "Visibility:" \
  --selected "$REPO_VIS" \
  "public" "private")"

# ── Action summary ────────────────────────────────────────────────────────────
echo ""
gum style \
  --border rounded --border-foreground 240 \
  --padding "0 2" \
  "$(printf "template:    %s\norg:         %s\nname:        %s\ndescription: %s\nvisibility:  %s\ncode-owner:  @%s\ncreate repo: %s\ncreate proj: %s" \
    "$OPT_TEMPLATE" "$OPT_ORG" "$OPT_NAME" \
    "${OPT_DESC:-<none>}" "$REPO_VIS" \
    "$CURRENT_USER" \
    "$( $CREATE_REPO && echo yes || echo no )" \
    "$( $CREATE_PROJECT && echo yes || echo no )")"
echo ""

if ! $DRY_RUN; then
  gum confirm "Proceed?" || { echo "Aborted."; exit 0; }
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
# Portable base64 (Linux: base64 -w0 / macOS: base64)
b64() { printf '%s' "$1" | base64 | tr -d '\n'; }

# ── Create repo ───────────────────────────────────────────────────────────────
REPO_CREATED=false
if $CREATE_REPO; then
  REPO_FULL="$OPT_ORG/$OPT_NAME"

  if $DRY_RUN; then
    info "[dry-run] gh repo create $REPO_FULL --$REPO_VIS --description \"$OPT_DESC\""
    info "[dry-run] push CODEOWNERS: * @$CURRENT_USER"
  else
    REPO_FLAGS=( --"$REPO_VIS" --enable-issues --disable-wiki )
    [[ -n "$OPT_DESC" ]] && REPO_FLAGS+=(--description "$OPT_DESC")

    if gh repo create "$REPO_FULL" "${REPO_FLAGS[@]}" 2>&1; then
      REPO_CREATED=true
      ok "Repository created: https://github.com/$REPO_FULL"

      # Apply topics
      TOPICS="$(jq -c '.repo.topics // []' "$TEMPLATE_JSON")"
      if [[ "$TOPICS" != "[]" ]]; then
        vecho "Setting topics: $TOPICS"
        TOPICS_PAYLOAD="$(jq -n --argjson t "$TOPICS" '{names: $t}')"
        gh api "repos/$REPO_FULL/topics" \
          -X PUT \
          -H "Accept: application/vnd.github+json" \
          --input - <<< "$TOPICS_PAYLOAD" \
          --silent 2>/dev/null || warn "Could not set topics (non-fatal)"
      fi

      # Push initial CODEOWNERS commit so the creator is code owner from day one
      vecho "Creating CODEOWNERS for @$CURRENT_USER"
      CODEOWNERS_BODY="$(jq -n \
        --arg msg "chore: set @${CURRENT_USER} as code owner" \
        --arg content "$(b64 "* @${CURRENT_USER}")" \
        '{message: $msg, content: $content}')"
      gh api "repos/$REPO_FULL/contents/.github/CODEOWNERS" \
        -X PUT \
        -H "Accept: application/vnd.github+json" \
        --input - <<< "$CODEOWNERS_BODY" \
        --silent 2>/dev/null \
        && ok "CODEOWNERS set (owner: @$CURRENT_USER)" \
        || warn "Could not create CODEOWNERS via API (add manually)"
    else
      warn "Repo creation failed or already exists — continuing"
    fi
  fi
fi

# ── Create GitHub Project v2 ──────────────────────────────────────────────────
PROJECT_NUMBER=""
if $CREATE_PROJECT; then
  PROJECT_TITLE="${OPT_NAME}"
  [[ -n "$OPT_DESC" ]] && PROJECT_TITLE_FULL="$PROJECT_TITLE — $OPT_DESC" \
                        || PROJECT_TITLE_FULL="$PROJECT_TITLE"

  if $DRY_RUN; then
    info "[dry-run] gh project create --owner $OPT_ORG --title \"$PROJECT_TITLE_FULL\""
  else
    PROJECT_NUMBER="$(gh project create \
      --owner "$OPT_ORG" \
      --title "$PROJECT_TITLE_FULL" \
      --format json 2>/dev/null | jq -r '.number')"

    if [[ -n "$PROJECT_NUMBER" && "$PROJECT_NUMBER" != "null" ]]; then
      ok "Project created: #$PROJECT_NUMBER"

      # Add custom fields from template JSON
      while IFS= read -r field_json; do
        FIELD_NAME="$(jq -r '.name' <<< "$field_json")"
        FIELD_TYPE="$(jq -r '.type' <<< "$field_json")"

        if [[ "$FIELD_TYPE" == "SINGLE_SELECT" ]]; then
          OPTIONS="$(jq -r '.options | join(",")' <<< "$field_json")"
          vecho "Adding field: $FIELD_NAME ($FIELD_TYPE)"
          gh project field-create "$PROJECT_NUMBER" \
            --owner "$OPT_ORG" \
            --name "$FIELD_NAME" \
            --data-type SINGLE_SELECT \
            --single-select-options "$OPTIONS" 2>/dev/null \
            && ok "  field: $FIELD_NAME" \
            || warn "  Could not add field '$FIELD_NAME' (may already exist)"
        elif [[ "$FIELD_TYPE" == "TEXT" ]]; then
          vecho "Adding field: $FIELD_NAME (TEXT)"
          gh project field-create "$PROJECT_NUMBER" \
            --owner "$OPT_ORG" \
            --name "$FIELD_NAME" \
            --data-type TEXT 2>/dev/null \
            && ok "  field: $FIELD_NAME" \
            || warn "  Could not add field '$FIELD_NAME'"
        fi
      done < <(jq -c '.fields[]' "$TEMPLATE_JSON")

      # Link repo to project
      if $REPO_CREATED; then
        vecho "Linking $OPT_ORG/$OPT_NAME to project #$PROJECT_NUMBER"
        gh project link "$PROJECT_NUMBER" \
          --owner "$OPT_ORG" \
          --repo "$OPT_ORG/$OPT_NAME" 2>/dev/null \
          && ok "Repo linked to project" \
          || warn "Could not auto-link repo (link manually in GitHub UI)"
      fi

      # View creation hints (GitHub CLI cannot create views programmatically)
      echo ""
      info "Recommended views — create manually in the project UI:"
      while IFS= read -r view_json; do
        VIEW_NAME="$(jq -r '.name' <<< "$view_json")"
        VIEW_NOTE="$(jq -r '.note // ""' <<< "$view_json")"
        echo "  • $VIEW_NAME  —  $VIEW_NOTE"
      done < <(jq -c '.views[]' "$TEMPLATE_JSON")

    else
      warn "Project creation failed. Create it manually: https://github.com/orgs/$OPT_ORG/projects/new"
    fi
  fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
gum style --foreground 212 "  Done!"
echo ""
[[ -n "$PROJECT_NUMBER" ]] \
  && echo "  Project:    https://github.com/orgs/$OPT_ORG/projects/$PROJECT_NUMBER"
( $CREATE_REPO && ! $DRY_RUN ) \
  && echo "  Repo:       https://github.com/$OPT_ORG/$OPT_NAME"
echo ""
if [[ "$OPT_TEMPLATE" == "ft-nixpkgs-flake" ]]; then
  echo "  Next steps:"
  echo "    1. Run create-flake (in ft-nixpkgs) to scaffold the flake files"
  echo "    2. Push the scaffold to the new repo"
  echo "    3. Run add-flake.sh to register in the ft-nixpkgs registry"
  echo "    4. Docs page is generated automatically on the next registry sync"
fi
echo ""
