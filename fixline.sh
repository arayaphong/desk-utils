#!/bin/bash

# Configuration for different applications
declare -A APP_CONFIGS=(
    ["linemediaplayer.exe"]="13 15"  # EDGE_OFFSET CORNER_OFFSET
    ["line.exe"]="10 20"             # EDGE_OFFSET CORNER_OFFSET
    # Add more applications as needed
)

readonly BORDER_INCREMENT=4  # Common increment for all applications

# Variables for tracking windows
declare -i current_id=0
declare -a edge_ids=()
declare -a corner_ids=()
declare current_app=""

# Function to show window borders
show_borders() {
    echo "SHOW $current_app: ($current_id)"
    # Show edge borders
    for edge_id in "${edge_ids[@]}"; do
        xdotool windowmap "$edge_id" 2>/dev/null || true
    done
    # Show corner borders
    for corner_id in "${corner_ids[@]}"; do
        xdotool windowmap "$corner_id" 2>/dev/null || true
    done
}

# Function to hide window borders
hide_borders() {
    echo "HIDE $current_app: ($current_id)"
    # Hide edge borders
    for edge_id in "${edge_ids[@]}"; do
        xdotool windowunmap "$edge_id" 2>/dev/null || true
    done
    # Hide corner borders
    for corner_id in "${corner_ids[@]}"; do
        xdotool windowunmap "$corner_id" 2>/dev/null || true
    done
}

# Calculate edge and corner window IDs based on the main window ID and app config
calculate_border_ids() {
    local main_id="$1"
    local app_name="$2"
    
    # Get app-specific offsets
    read -r edge_offset corner_offset <<< "${APP_CONFIGS[$app_name]}"
    
    # Calculate edge IDs
    edge_ids=()
    local edge_top=$((main_id + edge_offset))
    edge_ids+=("$edge_top")
    for ((i=1; i<4; i++)); do
        edge_ids+=("$((edge_top + i * BORDER_INCREMENT))")
    done
    
    # Calculate corner IDs
    corner_ids=()
    local corner_first=$((main_id + corner_offset))
    corner_ids+=("$corner_first")
    for ((i=1; i<4; i++)); do
        corner_ids+=("$((corner_first + i * BORDER_INCREMENT))")
    done
}

# Check if window exists and is valid
window_exists() {
    local win_id="$1"
    xwininfo -id "$win_id" &>/dev/null
    return $?
}

# Main function to handle window changes
handle_window_change() {
    local window_id="$1"
    
    # Skip invalid window IDs
    if [[ "$window_id" == "0x0" ]]; then
        return
    fi
    
    # Get window properties
    local xprop_output
    if ! xprop_output=$(xprop -id "$window_id" 2>/dev/null); then
        return
    fi
    
    # Extract WM_CLASS value - more robust pattern matching
    local wm_class
    wm_class=$(echo "$xprop_output" | grep -oP 'WM_CLASS\(STRING\) = ".*", "\K[^"]*')
    
    # If first method fails, try alternative extraction
    if [[ -z "$wm_class" ]]; then
        wm_class=$(echo "$xprop_output" | grep "WM_CLASS(STRING)" | awk -F '"' '{print $(NF-1)}')
    fi
    
    # Debug output
    echo "DEBUG: Window ID: $window_id, WM_CLASS: $wm_class" >&2
    
    # Check if this window belongs to any of our configured applications
    if [[ -n "$wm_class" ]] && [[ -n "${APP_CONFIGS[$wm_class]}" ]]; then
        # Convert hex to decimal
        current_id=$((0x${window_id#0x}))
        current_app="$wm_class"
        
        calculate_border_ids "$current_id" "$current_app"
        
        # Check if the first edge window exists before showing
        if window_exists "${edge_ids[0]}"; then
            show_borders
        else
            echo "WARNING: Border windows for $current_app ($current_id) not found" >&2
        fi
    else
        # Not our window, hide borders if we have a current ID
        if [[ $current_id -ne 0 ]]; then
            calculate_border_ids "$current_id" "$current_app"
            
            # Check if the first edge window exists before hiding
            if window_exists "${edge_ids[0]}"; then
                hide_borders
            fi
            
            # Reset tracking variables
            current_id=0
            current_app=""
        fi
    fi
}

# Set up signal handling with cleaner shutdown
cleanup() {
    echo "Script terminating, cleaning up..."
    # Hide any visible borders before exiting
    if [[ $current_id -ne 0 ]]; then
        calculate_border_ids "$current_id" "$current_app"
        hide_borders
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

# Function to log errors
log_error() {
    echo "ERROR: $*" >&2
}

# Check for required commands
for cmd in xprop xdotool xwininfo; do
    if ! command -v "$cmd" &>/dev/null; then
        log_error "$cmd is required but not installed. Please install it first."
        exit 1
    fi
done

# Display configuration
echo "Border manager started with the following configurations:"
for app in "${!APP_CONFIGS[@]}"; do
    read -r edge corner <<< "${APP_CONFIGS[$app]}"
    echo "  $app: EDGE_OFFSET=$edge, CORNER_OFFSET=$corner"
done

# Monitor active window changes - fixed xprop command
previous_window_id=""
xprop -root -spy _NET_ACTIVE_WINDOW | while read -r line; do
    current_window_id=$(echo "$line" | sed -n 's/^_NET_ACTIVE_WINDOW(WINDOW): window id # \(0x[0-9a-f]*\)/\1/p')
    
    # Only process if we have a valid window ID that's different from the previous one
    if [[ -n "$current_window_id" && "$current_window_id" != "$previous_window_id" ]]; then
        handle_window_change "$current_window_id"
        previous_window_id="$current_window_id"
    fi
done
