#!/usr/bin/env bash
# scripts/run_pipeline.sh
#
# End to end pipeline for the Archer Midnight FEA project.
# Runs the MATLAB analysis headlessly, verifies the figures landed on disk,
# stages any changes, commits, and pushes to the configured git remote.
#
# Usage:
#   ./scripts/run_pipeline.sh
#   ./scripts/run_pipeline.sh --no-push
#   ./scripts/run_pipeline.sh --no-commit
#   ./scripts/run_pipeline.sh --matlab /full/path/to/matlab
#   ./scripts/run_pipeline.sh --message "Updated LC2 results"
#
# Requirements: MATLAB R2019a or newer on PATH (or pass --matlab), git, bash.
# Tested on macOS and Ubuntu. Windows users: run via WSL or use the .ps1 sibling.

set -euo pipefail

# ---- defaults ----
DO_PUSH=1
DO_COMMIT=1
COMMIT_MSG="Automated pipeline run: refresh figures and results"
MATLAB_BIN=""

# ---- args ----
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-push)   DO_PUSH=0; shift ;;
    --no-commit) DO_COMMIT=0; DO_PUSH=0; shift ;;
    --matlab)    MATLAB_BIN="$2"; shift 2 ;;
    --message)   COMMIT_MSG="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1 ;;
  esac
done

# ---- locate the repo root ----
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
echo "[pipeline] repo root: $REPO_ROOT"

# ---- locate MATLAB ----
if [[ -z "$MATLAB_BIN" ]]; then
  if command -v matlab >/dev/null 2>&1; then
    MATLAB_BIN="$(command -v matlab)"
  else
    # Common install locations
    for candidate in \
      /Applications/MATLAB_R2024a.app/bin/matlab \
      /Applications/MATLAB_R2023b.app/bin/matlab \
      /Applications/MATLAB_R2023a.app/bin/matlab \
      /usr/local/MATLAB/R2024a/bin/matlab \
      /usr/local/MATLAB/R2023b/bin/matlab \
      /opt/MATLAB/R2024a/bin/matlab ; do
      if [[ -x "$candidate" ]]; then
        MATLAB_BIN="$candidate"; break
      fi
    done
  fi
fi

if [[ -z "$MATLAB_BIN" || ! -x "$MATLAB_BIN" ]]; then
  echo "[pipeline] ERROR: MATLAB binary not found." >&2
  echo "  Pass it explicitly:  $0 --matlab /Applications/MATLAB_R2024a.app/bin/matlab" >&2
  exit 2
fi
echo "[pipeline] matlab: $MATLAB_BIN"

# ---- snapshot figure timestamps so we can verify the run actually produced fresh output ----
FIG_DIR="$REPO_ROOT/docs/figures"
mkdir -p "$FIG_DIR"
BEFORE_LIST="$(mktemp)"
find "$FIG_DIR" -type f \( -name "*.png" -o -name "*.pdf" \) -printf '%f %T@\n' 2>/dev/null | sort > "$BEFORE_LIST" || true

# ---- run MATLAB headlessly ----
echo "[pipeline] running main.m in headless MATLAB. This can take 30 to 120 seconds."
LOG_FILE="$REPO_ROOT/data/last_run.log"
mkdir -p "$REPO_ROOT/data"

# Use -batch (R2019a+). Exits non-zero on MATLAB error.
"$MATLAB_BIN" -batch "addpath(genpath('src')); main" 2>&1 | tee "$LOG_FILE"

# ---- verify figures are fresh ----
AFTER_LIST="$(mktemp)"
find "$FIG_DIR" -type f \( -name "*.png" -o -name "*.pdf" \) -printf '%f %T@\n' 2>/dev/null | sort > "$AFTER_LIST" || true

NEW_OR_UPDATED="$(diff "$BEFORE_LIST" "$AFTER_LIST" | grep '^>' | wc -l | tr -d ' ')"
TOTAL_FIGURES="$(wc -l < "$AFTER_LIST" | tr -d ' ')"
echo "[pipeline] figures present: $TOTAL_FIGURES (new or updated this run: $NEW_OR_UPDATED)"

if [[ "$TOTAL_FIGURES" -eq 0 ]]; then
  echo "[pipeline] ERROR: no figures landed in docs/figures/. Check $LOG_FILE." >&2
  exit 3
fi

# ---- list the figures so the report writer (or you) knows what is available ----
echo "[pipeline] figure inventory:"
ls -1 "$FIG_DIR" | sed 's/^/  /'

# ---- git status, stage, commit, push ----
if [[ "$DO_COMMIT" -eq 1 ]]; then
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[pipeline] not a git repo. Initialize first:  git init  &&  git remote add origin <url>" >&2
    exit 4
  fi

  echo "[pipeline] git status before staging:"
  git status --short

  git add docs/figures/ docs/REPORT.md data/last_run.log data/results_summary.csv 2>/dev/null || true
  # Also catch any CSVs the pipeline produces
  git add data/*.csv 2>/dev/null || true

  if git diff --cached --quiet; then
    echo "[pipeline] no staged changes. Nothing to commit."
  else
    git commit -m "$COMMIT_MSG"
    echo "[pipeline] committed: $COMMIT_MSG"

    if [[ "$DO_PUSH" -eq 1 ]]; then
      CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
      echo "[pipeline] pushing branch $CURRENT_BRANCH to origin"
      git push origin "$CURRENT_BRANCH"
      echo "[pipeline] push complete."
    else
      echo "[pipeline] --no-push set, skipping git push."
    fi
  fi
fi

echo "[pipeline] done."
