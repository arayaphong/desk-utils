#!/usr/bin/env bash
# border-manager-improved.sh — Show/hide Wine edge-/corner-windows that act as borders
# -----------------------------------------------------------------------------
# * Case‑insensitive WM_CLASS matching
# * Toggle debug logging with -d
# * Custom BORDER_INCREMENT via -i
# * SIGINT/SIGTERM cleanup
# * shellcheck‑clean & safer error handling
#
# NOTE: IFS now includes a space so that `read` splits "13 15" correctly.
# -----------------------------------------------------------------------------

set -uo pipefail       # keep -u/o; omit -e so non‑zero cmds don't kill loop
IFS=$' \n\t'            # include <space> to let `read -r a b <<< "10 20"` split

# ──────────────────────────────  Global defaults  ─────────────────────────────
LOG_LEVEL="info"
BORDER_INCREMENT=4  # can be overridden via -i

# Declare per‑application EDGE_OFFSET and CORNER_OFFSET
#   key = WM_CLASS  (lower‑case, no quotes)
declare -A APP_CONFIGS=(
    [linemediaplayer.exe]="13 15"
    [line.exe]="10 20"
)

# ──────────────────────────────  Logging helpers  ─────────────────────────────
log() {
    local level="$1" msg="$2"
    case $level in debug) lvl=0;; info) lvl=1;; warn) lvl=2;; error) lvl=3;; esac
    case $LOG_LEVEL in debug) want=0;; info) want=1;; warn) want=2;; error) want=3;; esac
    (( lvl >= want )) && printf '%s: %s\n' "${level^^}" "$msg" >&2
}

debug() { log debug "$*"; }
info()  { log info  "$*"; }
warn()  { log warn  "$*"; }
error() { log error "$*"; }

# ────────────────────────────────  CLI options  ───────────────────────────────
usage() {
    cat <<EOF
Usage: $0 [-d] [-i increment]
  -d            Enable debug logging
  -i increment  Border-ID increment (default $BORDER_INCREMENT)
EOF
    exit 1
}

while getopts ':di:' opt; do
    case $opt in
        d) LOG_LEVEL="debug" ;;
        i) BORDER_INCREMENT="$OPTARG" ;;
        *) usage ;;
    esac
done
readonly BORDER_INCREMENT
shift $((OPTIND - 1))

# ──────────────────────────────  Helper functions  ────────────────────────────
get_wm_class() {
    xprop -id "$1" WM_CLASS 2>/dev/null | awk -F '"' '{print tolower($(NF-1))}'
}

window_exists() { xwininfo -id "$1" &>/dev/null; }

calculate_border_ids() {
    local main_id="$1" app_key="$2" edge_offset corner_offset
    read -r edge_offset corner_offset <<< "${APP_CONFIGS[$app_key]}"
    edge_ids=(); corner_ids=()
    for ((i=0;i<4;i++)); do
        edge_ids+=("$((main_id + edge_offset + i * BORDER_INCREMENT))")
        corner_ids+=("$((main_id + corner_offset + i * BORDER_INCREMENT))")
    done
}

map_ids()   { for id in "$@"; do xdotool windowmap   "$id" 2>/dev/null || true; done; }
unmap_ids() { for id in "$@"; do xdotool windowunmap "$id" 2>/dev/null || true; done; }

show_borders() { info "SHOW $current_app ($current_id)";   map_ids   "${edge_ids[@]}"; map_ids   "${corner_ids[@]}"; }
hide_borders() { info "HIDE $current_app ($current_id)";   unmap_ids "${edge_ids[@]}"; unmap_ids "${corner_ids[@]}"; }

cleanup()   { info 'Cleaning up…'; [[ $current_id -ne 0 ]] && hide_borders; }
trap cleanup SIGINT SIGTERM

# ────────────────────────────────  Sanity checks  ─────────────────────────────
for cmd in xprop xdotool xwininfo; do
    if ! command -v "$cmd" &>/dev/null; then error "$cmd is required"; exit 1; fi
done

info "Border manager started (increment=$BORDER_INCREMENT)"
for app in "${!APP_CONFIGS[@]}"; do
    read -r e c <<< "${APP_CONFIGS[$app]}"
    info "  $app: EDGE=$e CORNER=$c"
done

# ─────────────────────────────  Runtime variables  ────────────────────────────
current_id=0 current_app="" prev_window=""
edge_ids=() corner_ids=()

shopt -s nocasematch

# ───────────────────────────────  Event loop  ────────────────────────────────

xprop -root -spy _NET_ACTIVE_WINDOW | while read -r line; do
    active_hex=$(sed -n 's/^_NET_ACTIVE_WINDOW(WINDOW): window id # \(0x[0-9a-f]*\)/\1/p' <<< "$line")
    [[ -z "$active_hex" || "$active_hex" == "$prev_window" ]] && continue

    wm_class=$(get_wm_class "$active_hex")
    debug "Active=$active_hex class=$wm_class"

    if [[ -n "$wm_class" && -n "${APP_CONFIGS[$wm_class]:-}" ]]; then
        current_id=$((16#${active_hex#0x}))
        current_app="$wm_class"
        calculate_border_ids "$current_id" "$current_app"
        window_exists "${edge_ids[0]}" && show_borders
    else
        [[ $current_id -ne 0 ]] && window_exists "${edge_ids[0]}" && hide_borders
        current_id=0 current_app=""
    fi
    prev_window="$active_hex"
done
