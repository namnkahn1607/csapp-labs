#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

log()  { echo "[INFO] $*" >&2; }
warn() { echo "[WARN] $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: bash setup.sh <lab> [<lab> ...]
       bash setup.sh

Labs: data
EOF
}

refresh() {
    if [ "$#" -ne 4 ]; then
        die "Expected 4 params, received $#."
    fi

    wget "$1"
    tar -xvf "$2"
    mv "$3" "$4"
    rm "$2"
}

# ==============================================================================
# Data Lab
# ==============================================================================
DATA_URL="https://csapp.cs.cmu.edu/3e/datalab-handout.tar"
DATA_TAR="datalab-handout.tar"
DATA_SRC="datalab-handout"
DATA_DST="01_data"

# ==============================================================================
# Entry point
# ==============================================================================
main() {
    [[ $# -ge 1 ]] || { usage; exit 1; }

    local labs=("$@")
    for lab in "${labs[@]}"; do
        case "$lab" in
            data)  refresh "$DATA_URL" "$DATA_TAR" "$DATA_SRC" "$DATA_DST" ;;
            *) die "Unknown lab: '$lab'. Run without args to see usage." ;;
        esac
    done
}

main "$@"
