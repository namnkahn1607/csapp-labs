#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

log()  { echo "[INFO] $*" >&2; }
warn() { echo "[WARN] $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

BASE_URL="https://csapp.cs.cmu.edu/3e"

# name:tarball:destination
LABS=(
    "data:datalab-handout.tar:01_data"
    "bomb:bomb.tar:02_bomb"
    "attack:target1.tar:03_attack"
    "arch:archlab-handout.tar:04_architecture"
    "cache:cachelab-handout.tar:05_cache"
    "perf:perflab-handout.tar:06_performance"
    "shell:shlab-handout.tar:07_shell"
    "malloc:malloclab-handout.tar:08_malloc"
    "proxy:proxylab-handout.tar:09_proxy"
)

FORCE=0
TMP_ROOT=""

usage() {
    local entry names=""
    for entry in "${LABS[@]}"; do names+="${entry%%:*} "; done
    cat <<EOF
Usage: bash setup.sh [-f|--force] <lab> [<lab> ...]
       bash setup.sh [-f|--force] all
       bash setup.sh -h|--help
 
Labs: ${names}
 
Existing lab directories are DELETED and replaced by a fresh handout.
Without --force you are asked to confirm each overwrite.
EOF
}

cleanup() {
    [ -n "$TMP_ROOT" ] && rm -rf -- "$TMP_ROOT"
}

# fetch <url> <out-file>
fetch() {
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "$2" "$1"
    elif command -v curl >/dev/null 2>&1; then
        curl -fL --progress-bar -o "$2" "$1"
    else
        die "Neither wget nor curl found."
    fi
}

# confirm_overwrite <dir>
confirm_overwrite() {
    [[ "$FORCE" -eq 1 ]] && return 0
    [[ -t 0 ]] || die "'$1' exists but stdin is not a TTY. Re-run with --force to overwrite."

    warn "'$1' exists. Current lab progress will be overwritten."
    local ans
    read -r -p "Overwrite '$1'? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]]
}

# lab_spec <name> -> prints "name:tar:dst", returns 1 if unknown
lab_spec() {  
    local entry
    for entry in "${LABS[@]}"; do
        if [ "${entry%%:*}" = "$1" ]; then
            echo "$entry"
            return 0
        fi
    done
    return 1
}

# extract_nested <dir> -> unpack every *.tar under <dir> until none are left
extract_nested() {
    local dir="$1" pass=0 found f
    while :; do
        found=0
        while IFS= read -r -d '' f; do
            found=1
            log "unpacking nested $(basename "$f")"
            tar -xf "$f" -C "$(dirname "$f")"
            rm -f -- "$f"
        done < <(find "$dir" -type f -name '*.tar' -print0)
        [ "$found" -eq 0 ] && return 0
        pass=$((pass + 1))
        [ "$pass" -lt 8 ] || die "Nested tar depth exceeds 8 under '$dir'."
    done
}

# refresh <name> <tar-name> <dst-dir>
refresh() {
    if [ "$#" -ne 3 ]; then
        die "Expected 3 params <name> <tar-name> <dst-dir>, received $#."
    fi
    local name="$1" tar_name="$2" dst="$3"
    local work="$TMP_ROOT/$name"

    # Download + extract into a scratch location.
    # A network failure cannot cost the user their progress.
    mkdir -p "$work/extracted"
    log "[$name] downloading $tar_name"
    fetch "$BASE_URL/$tar_name" "$work/$tar_name"
    tar -xf "$work/$tar_name" -C "$work/extracted"

    # Normalize layout: everything needs to be inside a single root directory.
    local entries=("$work/extracted"/*) src="$work/extracted"
    if [ "${#entries[@]}" -eq 1 ] && [ -d "${entries[0]}" ]; then
        src="${entries[0]}"
    fi

    extract_nested "$src"

    # Move handout into destination.
    if [ -e "$dst" ]; then
        confirm_overwrite "$dst" || { warn "[$name] skipped."; return 0; }
        rm -rf -- "$dst"
    fi
    mv -- "$src" "$dst"
    log "[$name] ready at $SCRIPT_DIR/$dst"
}

# =============================================================================
# Entry point
# =============================================================================
main() {
    local requested=() arg entry
    for arg in "$@"; do
        case "$arg" in
            -h|--help)  usage; exit 0 ;;
            -f|--force) FORCE=1 ;;
            all)        for entry in "${LABS[@]}"; do requested+=("${entry%%:*}"); done ;;
            -*)         die "Unknown option: '$arg'." ;;
            *)          requested+=("$arg") ;;
        esac
    done

    [ "${#requested[@]}" -ge 1 ] || { usage; exit 1; }

    # Validate requested lab names to see if they're available.
    for arg in "${requested[@]}"; do
        lab_spec "$arg" >/dev/null || die "Unknown lab: '$arg'. Run with --help to see usage."
    done

    TMP_ROOT="$(mktemp -d "$SCRIPT_DIR/.setup.XXXXXX")"
    trap cleanup EXIT

    local spec name tar_name dst
    for arg in "${requested[@]}"; do
        spec="$(lab_spec "$arg")"
        IFS=: read -r name tar_name dst <<<"$spec"
        refresh "$name" "$tar_name" "$dst"
    done
}

main "$@"
