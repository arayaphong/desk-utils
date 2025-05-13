#!/usr/bin/env bash
# fixline.sh — Show/hide Wine edge-/corner-windows that act as borders
# -----------------------------------------------------------------------------
# * Case-insensitive WM_CLASS matching
# * Toggle debug logging with -d
# * Custom BORDER_INCREMENT via -i
# * Track multiple windows, re-show on focus
# * Hide on unfocus (all others) & on actual close
# * Cleanup on SIGINT/SIGTERM
# -----------------------------------------------------------------------------

set -uo pipefail
IFS=$' \n\t' # include space so `read -r a b <<< "10 20"` splits correctly

# ──────────────────────────────  Global defaults  ─────────────────────────────
LOG_LEVEL="info"
BORDER_INCREMENT=4

# Lower-case WM_CLASS → "EDGE_OFFSET CORNER_OFFSET"
declare -A APP_CONFIGS=(
  [linemediaplayer.exe]="13 15"
  [line.exe]="10 16"
)

# ──────────────────────────────  Logging helpers  ─────────────────────────────
log() {
  local lvlname=$1 msg=$2 lvl want
  case $lvlname in debug) lvl=0 ;; info) lvl=1 ;; warn) lvl=2 ;; error) lvl=3 ;; esac
  case $LOG_LEVEL in debug) want=0 ;; info) want=1 ;; warn) want=2 ;; error) want=3 ;; esac
  ((lvl >= want)) && printf '%s: %s\n' "${lvlname^^}" "$msg" >&2
}
debug() { log debug "$*"; }
info() { log info "$*"; }
warn() { log warn "$*"; }
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

# ──────────────────────────────  Sanity checks  ─────────────────────────────
for cmd in xprop xwininfo xdotool; do
  if ! command -v "$cmd" &>/dev/null; then
    error "$cmd is required"
    exit 1
  fi
done

info "Starting border manager (increment=$BORDER_INCREMENT)"
for app in "${!APP_CONFIGS[@]}"; do
  read -r e c <<<"${APP_CONFIGS[$app]}"
  info "  Match '$app' → EDGE=$e CORNER=$c"
done

# ──────────────────────────────  Helper functions  ────────────────────────────
get_wm_class() {
  xprop -id "$1" WM_CLASS 2>/dev/null |
    awk -F\" '{ print tolower($(NF-1)) }'
}

window_exists() {
  xwininfo -id "$1" &>/dev/null
}

calculate_border_ids() {
  local main_id=$1 app_key=$2 edge_offset corner_offset
  read -r edge_offset corner_offset <<<"${APP_CONFIGS[$app_key]}"
  edge_ids=()
  corner_ids=()
  for ((i = 0; i < 4; i++)); do
    edge_ids+=("$((main_id + edge_offset + i * BORDER_INCREMENT))")
    corner_ids+=("$((main_id + corner_offset + i * BORDER_INCREMENT))")
  done
}

map_ids() { for id; do xdotool windowmap "$id" 2>/dev/null || true; done; }
unmap_ids() { for id; do xdotool windowunmap "$id" 2>/dev/null || true; done; }

show_borders() {
  info "SHOW $current_app ($current_id)"
  map_ids "${edge_ids[@]}"
  map_ids "${corner_ids[@]}"
}

hide_borders() {
  info "HIDE $current_app ($current_id)"
  unmap_ids "${edge_ids[@]}"
  unmap_ids "${corner_ids[@]}"
}

# ──────────────────────────────  Multi-window state & cleanup ───────────────────
declare -A open_windows=() # window_hex_id → wm_class
prev_event=""

cleanup_closed() {
  for win in "${!open_windows[@]}"; do
    if ! xprop -id "$win" &>/dev/null; then
      wm_class=${open_windows[$win]}
      current_id=$((16#${win#0x}))
      current_app="$wm_class"
      calculate_border_ids "$current_id" "$wm_class"
      hide_borders
      unset open_windows["$win"]
    fi
  done
}

cleanup_all() {
  info "Cleaning up all borders…"
  for win in "${!open_windows[@]}"; do
    wm_class=${open_windows[$win]}
    current_id=$((16#${win#0x}))
    current_app="$wm_class"
    calculate_border_ids "$current_id" "$wm_class"
    hide_borders
  done
  exit
}
trap cleanup_all SIGINT SIGTERM

# ─────────────────────────────── Event loop ────────────────────────────────
xprop -root -spy _NET_ACTIVE_WINDOW | while read -r line; do
  # extract "0x..." window ID
  active_hex=$(sed -n \
    's/^_NET_ACTIVE_WINDOW(WINDOW): window id # \(0x[0-9a-f]*\)/\1/p' \
    <<<"$line")
  [[ -z "$active_hex" || "$active_hex" == "$prev_event" ]] && continue

  cleanup_closed

  # Hide borders for every other tracked window
  for win in "${!open_windows[@]}"; do
    if [[ "$win" != "$active_hex" ]]; then
      wm_class=${open_windows[$win]}
      current_id=$((16#${win#0x}))
      current_app="$wm_class"
      calculate_border_ids "$current_id" "$wm_class"
      hide_borders
      unset open_windows["$win"]
    fi
  done

  wm_class=$(get_wm_class "$active_hex")
  debug "Focus change → $active_hex (class=$wm_class)"

  # Only lookup APP_CONFIGS if wm_class is non-empty
  if [[ -n "$wm_class" && ${APP_CONFIGS[$wm_class]+_} ]]; then
    current_id=$((16#${active_hex#0x}))
    current_app="$wm_class"
    calculate_border_ids "$current_id" "$wm_class"
    window_exists "${edge_ids[0]}" && show_borders
    open_windows["$active_hex"]="$wm_class"
  fi

  prev_event="$active_hex"
done
