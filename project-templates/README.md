# Project Templates

Org-wide scaffolding for FT-nixforge GitHub repos and Projects v2.

> **Requires org membership.** `create-project.sh` verifies that you are a
> member of the target organisation before creating anything.

## Templates

### `ft-nixpkgs-flake`
For individual flakes that live inside the **ft-nixpkgs** ecosystem.

**Project fields:** Status · Priority · Type · Nix Component  
**Views:** Board (by Status) · All Issues (table)  
**Repo scaffold:** `flake.nix` · `ft-nixpkgs.json` · `README.md` · `.gitignore`  
**Code owner:** the org member who runs the script (`CODEOWNERS` → `* @you`)

### `nix-project`
For standalone NixOS-compatible projects (tools, larger flakes, integrations).

**Project fields:** Status · Priority · Type · Size · Milestone  
**Views:** Board · All Items · Roadmap · Current Sprint  
**Repo scaffold:** `README.md` · `.gitignore`  
**Code owner:** the org member who runs the script (`CODEOWNERS` → `* @you`)

---

## Usage

### Prerequisites

```bash
# GitHub CLI authenticated with org access
gh auth login

# Dependencies (available via nix shell)
nix shell nixpkgs#gh nixpkgs#jq nixpkgs#gum
```

### Run the script

```bash
# Clone this repo
git clone https://github.com/FT-nixforge/.github
cd .github

# Interactive mode
bash project-templates/create-project.sh

# Non-interactive
bash project-templates/create-project.sh \
  --template ft-nixpkgs-flake \
  --name ft-myflake \
  --desc "My new flake" \
  --org FT-nixforge
```

### Flags

| Flag | Description |
|------|-------------|
| `--template` | `ft-nixpkgs-flake` or `nix-project` |
| `--name` | Repo / project name |
| `--desc` | Short description |
| `--org` | GitHub org (default: `FT-nixforge`) |
| `--no-repo` | Skip repo creation |
| `--no-project` | Skip project creation |
| `--dry-run` / `-n` | Preview only — no API calls |
| `--verbose` / `-v` | Extra output |

---

## What the script does

1. **Checks** that your `gh`-authenticated user is a member of the org  
2. **Creates** the GitHub repo in the org (with topics, issues enabled)  
3. **Pushes** an initial `.github/CODEOWNERS` commit — so *you* are the code
   owner of all files from day one, even though the repo lives in the org  
4. **Creates** a GitHub Projects v2 board with all template fields  
5. **Links** the repo to the project  
6. Prints hints for views (views cannot be created via API yet)

---

## Integration with `create-flake`

When creating a new ft-nixpkgs flake, the full workflow is:

```bash
# 1. Scaffold repo + project (this script)
bash project-templates/create-project.sh --template ft-nixpkgs-flake --name ft-myflake

# 2. Scaffold the flake files (in ft-nixpkgs checkout)
nix run .#create-flake -- ft-myflake

# 3. Push scaffold to the new repo
cd ../ft-myflake
git remote add origin https://github.com/FT-nixforge/ft-myflake
git push -u origin main

# 4. Register in ft-nixpkgs
bash scripts/add-flake.sh FT-nixforge/ft-myflake

# 5. Docs generate automatically on next registry sync
```

### Optional: add `--create-project` to `create-flake.sh`

Append this block to `ft-nixpkgs/scripts/create-flake.sh` after the git init
section to auto-prompt for repo + project creation:

```bash
# ── Optional: create GitHub org repo + project ────────────────────────────────
COMMUNITY_ORG_REPO="${FT_GITHUB_DOT:-}"
if [[ -z "$COMMUNITY_ORG_REPO" ]]; then
  # Auto-detect sibling clone of FT-nixforge/.github
  _candidate="$(cd "$(dirname "${FT_REPO_ROOT:-$PWD}")" && pwd)/.github"
  [[ -d "$_candidate/project-templates" ]] && COMMUNITY_ORG_REPO="$_candidate"
fi

if [[ -n "$COMMUNITY_ORG_REPO" ]] && command -v gh &>/dev/null; then
  if gum confirm "Create GitHub org repo + Project for $CF_NAME?"; then
    bash "$COMMUNITY_ORG_REPO/project-templates/create-project.sh" \
      --template ft-nixpkgs-flake \
      --name "$CF_NAME" \
      --desc "$CF_DESC" \
      --org "$CF_OWNER" \
      $( $DRY_RUN && echo "--dry-run" )
  fi
fi
```

Set `FT_GITHUB_DOT=/path/to/.github-clone` in your environment if needed.

---

## File structure

```
project-templates/
├── README.md                            ← this file
├── create-project.sh                    ← automation script
│
├── ft-nixpkgs-flake/
│   ├── project.json                     ← Projects v2 field definitions
│   └── repo/
│       ├── .github/
│       │   └── CODEOWNERS               ← * @{{OWNER}} (substituted at creation)
│       ├── README.md
│       ├── flake.nix
│       ├── ft-nixpkgs.json
│       └── .gitignore
│
└── nix-project/
    ├── project.json                     ← Projects v2 field definitions
    └── repo/
        ├── .github/
        │   └── CODEOWNERS               ← * @{{OWNER}} (substituted at creation)
        ├── README.md
        └── .gitignore
```
