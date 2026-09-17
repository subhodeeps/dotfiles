#!/usr/bin/env bash
set -euo pipefail

# Defaults
NAME="numerics"
ROOT="${VENV_ROOT:-$HOME/venvs}"
YES=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [-e ENV] [-r ROOT] [-y] [PACKAGE...]
  -e ENV    env name (default: numerics)
  -r ROOT   venv folder (default: \$VENV_ROOT or ~/venvs)
  -y        apply without asking
  PACKAGE   upgrade only these packages (default: everything)
EOF
}

while getopts ":e:r:yh" opt; do
  case $opt in
    e) NAME="$OPTARG" ;;
    r) ROOT="$OPTARG" ;;
    y) YES=1 ;;
    h) usage; exit 0 ;;
    :) echo "Option -$OPTARG needs a value" >&2; usage; exit 1 ;;
    *) echo "Unknown option -$OPTARG" >&2; usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

ENV="$ROOT/$NAME"
DIR="$ROOT/$NAME.lock"
PY="$ENV/bin/python"
STAMP=$(date +%F-%H%M%S)
BACKUP="$DIR/backups/$STAMP.txt"
NEW="$DIR/requirements.new.txt"
PKGS=("$@")   # optional: upgrade only these packages
STAGE="prep"  # prep -> sync -> done

# Sanity checks
command -v uv >/dev/null || { echo "uv not found on PATH" >&2; exit 1; }
[[ -x "$PY" ]] || { echo "No venv at $ENV" >&2; exit 1; }
[[ -f "$DIR/requirements.in" ]] || { echo "Missing $DIR/requirements.in" >&2; exit 1; }
mkdir -p "$DIR/backups"

# Per-env uv settings (e.g. UV_TORCH_BACKEND=cu126)
if [[ -f "$DIR/uv.env" ]]; then set -a; source "$DIR/uv.env"; set +a; fi

# Rollback command (includes per-env uv settings if any)
RB="uv pip sync $BACKUP --python $PY"
if [[ -f "$DIR/uv.env" ]]; then
  RB="env $(grep -Ev '^\s*(#|$)' "$DIR/uv.env" | xargs) $RB"
fi

# One run per env at a time
exec 9>"$DIR/.upgrade.lock"
flock -n 9 || { echo "Another upgrade of $NAME is running" >&2; exit 1; }

cleanup() {
  local rc=$?
  rm -f "$NEW"
  if (( rc != 0 )) && [[ $STAGE == sync ]]; then
    echo >&2
    echo "FAILED after the env was modified. Roll back with:" >&2
    echo "  $RB" >&2
  fi
}
trap cleanup EXIT

echo "Env: $ENV"

# Normalise names (case, _ and .) so the diff shows only real changes
norm() {
  grep -Ev '^\s*(#|$)' "$1" |
  awk '{ match($0,/^[^=@ ]+/); n=tolower(substr($0,1,RLENGTH));
         gsub(/[_.]/,"-",n); print n substr($0,RLENGTH+1) }' | sort
}

# Guard: the venv breaks when the base Python is upgraded
"$PY" -c 'import sys' 2>/dev/null || {
  echo "venv Python is broken (system Python upgraded?). Rebuild with:" >&2
  echo "  uv venv --clear $ENV --python /usr/bin/python" >&2
  echo "  $(basename "$0") -e $NAME -r $ROOT" >&2
  exit 1; }

# 1. Snapshot the current env (rollback point)
uv pip freeze --python "$PY" > "$BACKUP"

# 2. Resolve: everything, or only the named packages
rm -f "$NEW"
if (( ${#PKGS[@]} )); then
  UPG=(); for p in "${PKGS[@]}"; do UPG+=(-P "$p"); done
  # keep everything else at its current version
  if [[ -f "$DIR/requirements.txt" ]]; then
    cp "$DIR/requirements.txt" "$NEW"
  else
    cp "$BACKUP" "$NEW"
  fi
  uv pip compile "$DIR/requirements.in" "${UPG[@]}" --python "$PY" \
    --no-header --no-annotate -o "$NEW"
  for p in "${PKGS[@]}"; do
    n=$(printf '%s' "$p" | tr 'A-Z_.' 'a-z--')
    norm "$NEW" | grep -Eq "^${n}(==| @)" || echo "Warning: '$p' is not in the resolved env (typo?)" >&2
  done
else
  uv pip compile "$DIR/requirements.in" --upgrade --python "$PY" \
    --no-header --no-annotate -o "$NEW"
fi

# 3. Review
echo "=== Changes (< current, > new) ==="
diff <(norm "$BACKUP") <(norm "$NEW") || true
if (( ! YES )); then
  if [[ -t 0 ]]; then
    read -rp "Apply? [y/N] " ans
  else
    ans=n; echo "No terminal and no -y; not applying."
  fi
  [[ "$ans" == [yY] ]] || { echo "Aborted; env untouched."; rm -f "$BACKUP"; exit 0; }
fi

# 4. Apply to the same env
STAGE="sync"
uv pip sync "$NEW" --python "$PY"
mv "$NEW" "$DIR/requirements.txt"

# 5. Verify
uv pip check --python "$PY"
if [[ -f "$DIR/smoke.py" ]]; then "$PY" "$DIR/smoke.py"; fi
STAGE="done"

echo "Rollback: $RB"