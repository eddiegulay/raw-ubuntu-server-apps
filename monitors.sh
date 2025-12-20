#!/bin/bash

# monitors.sh - Console Display Manager
# 

# ==============================================================================
# Global State
# ==============================================================================
declare -a OUTPUTS              # List of all output names
declare -A STATE_CONNECTED      # [name] -> "1" (connected) or "0" (disconnected)
declare -A STATE_ENABLED        # [name] -> "1" (enabled) or "0" (disabled)
declare -A STATE_PRIMARY        # [name] -> "1" (is primary) or ""
declare -A STATE_MODE           # [name] -> "WxH" (current mode)
declare -A STATE_POS_X          # [name] -> int
declare -A STATE_POS_Y          # [name] -> int
declare -A AVAILABLE_MODES      # [name] -> "mode1 mode2 ..." (space separated)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ==============================================================================
# Parsing Logic
# ==============================================================================
parse_xrandr() {
    # Reset state
    OUTPUTS=()
    STATE_CONNECTED=()
    STATE_ENABLED=()
    STATE_PRIMARY=()
    STATE_MODE=()
    STATE_POS_X=()
    STATE_POS_Y=()
    AVAILABLE_MODES=()

    local current_output=""
    
    while IFS= read -r line; do
        # check if line starts with space (mode line)
        if [[ "$line" =~ ^\  ]]; then
            if [[ -n "$current_output" ]]; then
                # Extract mode resolution (first word)
                local mode=$(echo "$line" | awk '{print $1}')
                AVAILABLE_MODES[$current_output]="${AVAILABLE_MODES[$current_output]} $mode"
            fi
            continue
        fi

        # Otherwise it's an output line
        # Regex to capture: Name, State, anything else
        if [[ "$line" =~ ^([a-zA-Z0-9-]+)\ (connected|disconnected)\ (.*) ]]; then
            local name="${BASH_REMATCH[1]}"
            local state="${BASH_REMATCH[2]}"
            local rest="${BASH_REMATCH[3]}"
            
            OUTPUTS+=("$name")
            current_output="$name"
            
            if [[ "$state" == "connected" ]]; then
                STATE_CONNECTED[$name]="1"
                
                # Check for primary
                if [[ "$rest" =~ primary ]]; then
                    STATE_PRIMARY[$name]="1"
                fi
                
                # Check for geometry: WxH+X+Y
                # Matches: 1920x1080+0+0
                if [[ "$rest" =~ ([0-9]+)x([0-9]+)\+([0-9]+)\+([0-9]+) ]]; then
                    STATE_ENABLED[$name]="1"
                    STATE_MODE[$name]="${BASH_REMATCH[1]}x${BASH_REMATCH[2]}"
                    STATE_POS_X[$name]="${BASH_REMATCH[3]}"
                    STATE_POS_Y[$name]="${BASH_REMATCH[4]}"
                else
                    STATE_ENABLED[$name]="0"
                fi
            else
                STATE_CONNECTED[$name]="0"
                STATE_ENABLED[$name]="0"
            fi
        fi
    done < <(xrandr -q)
}

# ==============================================================================
# Helpers
# ==============================================================================
select_output() {
    echo "Select output:" >&2
    local i=1
    local valid_indices=()
    local selection_map=()

    for out in "${OUTPUTS[@]}"; do
        echo "$i) $out" >&2
        selection_map[$i]=$out
        ((i++))
    done

    local choice
    read -p "#? " choice >&2
    
    if [[ -n "${selection_map[$choice]}" ]]; then
        echo "${selection_map[$choice]}"
    else
        echo ""
    fi
}

# ==============================================================================
# Actions
# ==============================================================================

action_enable_disable() {
    local out=$(select_output)
    [[ -z "$out" ]] && return

    echo "Current state: Enabled=${STATE_ENABLED[$out]}"
    echo "1. Enable"
    echo "2. Disable"
    read -p "Choice: " choice

    if [[ "$choice" == "1" ]]; then
        STATE_ENABLED[$out]="1"
        # If no mode set, set default (first one available)
        if [[ -z "${STATE_MODE[$out]}" ]]; then
             local first_mode=$(echo "${AVAILABLE_MODES[$out]}" | awk '{print $1}')
             STATE_MODE[$out]="$first_mode"
             echo "Set default mode: $first_mode"
        fi
        
        # If no position set, default to 0x0
        if [[ -z "${STATE_POS_X[$out]}" ]]; then
             STATE_POS_X[$out]="0"
             STATE_POS_Y[$out]="0"
        fi
        
    elif [[ "$choice" == "2" ]]; then
        STATE_ENABLED[$out]="0"
    fi
}

action_primary() {
    local out=$(select_output)
    [[ -z "$out" ]] && return
    
    if [[ "${STATE_ENABLED[$out]}" != "1" ]]; then
        echo -e "${RED}Error: Display must be enabled to be primary.${NC}"
        read -p "Press Enter..."
        return
    fi

    # Clear other primaries
    for o in "${OUTPUTS[@]}"; do
        STATE_PRIMARY[$o]=""
    done
    
    STATE_PRIMARY[$out]="1"
    echo "Set $out as primary."
}


get_dimensions() {
    local out="$1"
    local mode="${STATE_MODE[$out]}"
    if [[ "$mode" =~ ([0-9]+)x([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    else
        echo "0 0"
    fi
}

normalize_positions() {
    local min_x=99999
    local min_y=99999

    # Find minimums
    for out in "${OUTPUTS[@]}"; do
        if [[ "${STATE_ENABLED[$out]}" == "1" ]]; then
            [[ "${STATE_POS_X[$out]}" -lt "$min_x" ]] && min_x="${STATE_POS_X[$out]}"
            [[ "${STATE_POS_Y[$out]}" -lt "$min_y" ]] && min_y="${STATE_POS_Y[$out]}"
        fi
    done

    # Shift all
    for out in "${OUTPUTS[@]}"; do
        if [[ "${STATE_ENABLED[$out]}" == "1" ]]; then
            STATE_POS_X[$out]=$((STATE_POS_X[$out] - min_x))
            STATE_POS_Y[$out]=$((STATE_POS_Y[$out] - min_y))
        fi
    done
}

action_extend() {
    echo "Select Reference Display (must be enabled):"
    local ref=$(select_output)
    [[ -z "$ref" ]] && return
    if [[ "${STATE_ENABLED[$ref]}" != "1" ]]; then
        echo -e "${RED}Error: Reference display must be enabled.${NC}"
        return
    fi
    
    echo "Select Target Display (to move/enable):"
    local diff_outputs=()
    local i=1
    local selection_map=()
    for out in "${OUTPUTS[@]}"; do
        if [[ "$out" != "$ref" ]]; then
            echo "$i) $out"
            selection_map[$i]=$out
            ((i++))
        fi
    done
    read -p "#? " choice
    local target="${selection_map[$choice]}"
    [[ -z "$target" ]] && return

    echo "Direction for $target relative to $ref:"
    echo "1. Right"
    echo "2. Left"
    echo "3. Above"
    echo "4. Below"
    read -p "Choice: " dir

    # Ensure target is enabled and has mode
    STATE_ENABLED[$target]="1"
    if [[ -z "${STATE_MODE[$target]}" ]]; then
        local first_mode=$(echo "${AVAILABLE_MODES[$target]}" | awk '{print $1}')
        STATE_MODE[$target]="$first_mode"
        echo "Enabled $target with mode $first_mode"
    fi

    # Get dimensions
    read -r ref_w ref_h <<< $(get_dimensions "$ref")
    read -r tgt_w tgt_h <<< $(get_dimensions "$target")
    
    local ref_x="${STATE_POS_X[$ref]}"
    local ref_y="${STATE_POS_Y[$ref]}"
    
    case $dir in
        1) # Right
            STATE_POS_X[$target]=$((ref_x + ref_w))
            STATE_POS_Y[$target]=$((ref_y))
            ;;
        2) # Left
            STATE_POS_X[$target]=$((ref_x - tgt_w))
            STATE_POS_Y[$target]=$((ref_y))
            ;;
        3) # Above
            STATE_POS_X[$target]=$((ref_x))
            STATE_POS_Y[$target]=$((ref_y - tgt_h))
            ;;
        4) # Below
            STATE_POS_X[$target]=$((ref_x))
            STATE_POS_Y[$target]=$((ref_y + ref_h))
            ;;
        *) echo "Invalid choice"; return ;;
    esac
    
    normalize_positions
    echo "Layout updated."
}

action_mirror() {
    echo "Select Source (Master):"
    local src=$(select_output)
    [[ -z "$src" ]] && return
    if [[ "${STATE_ENABLED[$src]}" != "1" ]]; then
        echo -e "${RED}Error: Source must be enabled.${NC}"
        return
    fi

    echo "Select Target (Mirror):"
    # filter out src
    local i=1
    local selection_map=()
    for out in "${OUTPUTS[@]}"; do
        if [[ "$out" != "$src" ]]; then
            echo "$i) $out"
            selection_map[$i]=$out
            ((i++))
        fi
    done
    read -p "#? " choice
    local target="${selection_map[$choice]}"
    [[ -z "$target" ]] && return

    # Find common modes
    local common_mode=""
    # Simple check: take src mode, see if target has it.
    # Ideally should find highest common, but let's try strict matching first.
    # Or, list all src modes and check intersection.
    
    local src_modes="${AVAILABLE_MODES[$src]}"
    local tgt_modes="${AVAILABLE_MODES[$target]}"
    
    # Iterate src modes (highest first usually)
    for m in $src_modes; do
        if [[ "$tgt_modes" =~ $m ]]; then
            common_mode="$m"
            break
        fi
    done
    
    if [[ -z "$common_mode" ]]; then
        echo -e "${RED}No common mode found between $src and $target${NC}"
        return
    fi
    
    echo "Mirroring using common mode: $common_mode"
    STATE_ENABLED[$target]="1"
    STATE_MODE[$src]="$common_mode"
    STATE_MODE[$target]="$common_mode"
    STATE_POS_X[$target]="${STATE_POS_X[$src]}"
    STATE_POS_Y[$target]="${STATE_POS_Y[$src]}"
}

validate_state() {
    local enabled_count=0
    local primary_count=0
    
    for out in "${OUTPUTS[@]}"; do
        if [[ "${STATE_ENABLED[$out]}" == "1" ]]; then
            ((enabled_count++))
            # Check for mode
            if [[ -z "${STATE_MODE[$out]}" ]]; then
                echo -e "${RED}Error: Enabled display $out has no mode set.${NC}"
                return 1
            fi
            # Check for pos
            if [[ -z "${STATE_POS_X[$out]}" ]]; then
                 # Auto set to 0 if missing (should result in overlap warnings but it's valid for xrandr)
                 STATE_POS_X[$out]=0
                 STATE_POS_Y[$out]=0
            fi
        fi
        
        if [[ "${STATE_PRIMARY[$out]}" == "1" ]]; then
           # Must be enabled
           if [[ "${STATE_ENABLED[$out]}" != "1" ]]; then
               echo -e "${RED}Error: Primary display $out is disabled.${NC}"
               return 1
           fi
           ((primary_count++))
        fi
    done

    if [[ "$enabled_count" -lt 1 ]]; then
        echo -e "${RED}Error: At least one display must be enabled.${NC}"
        return 1
    fi
    
    if [[ "$primary_count" -ne 1 ]]; then
        echo -e "${RED}Error: Exactly one primary display required (found $primary_count).${NC}"
        return 1
    fi
    
    return 0
}

save_layout() {
    if ! validate_state; then
        echo "Validation failed. Layout not saved."
        return
    fi

    # directory exists?
    mkdir -p ~/.screenlayout

    local cmd="xrandr"
    
    # Sort outputs to ensure determinism? Not strictly needed but good.
    # We iterate OUTPUTS
    
    for out in "${OUTPUTS[@]}"; do
        if [[ "${STATE_ENABLED[$out]}" == "1" ]]; then
            cmd+=" --output $out --mode ${STATE_MODE[$out]} --pos ${STATE_POS_X[$out]}x${STATE_POS_Y[$out]} --rotate normal"
            if [[ "${STATE_PRIMARY[$out]}" == "1" ]]; then
                cmd+=" --primary"
            fi
        else
            # Explicitly disable
            cmd+=" --output $out --off"
        fi
    done

    local file=~/.screenlayout/current.sh
    echo "#!/bin/sh" > "$file"
    echo "$cmd" >> "$file"
    chmod +x "$file"
    
    echo -e "${GREEN}Layout saved to $file${NC}"
    echo "Command generated:"
    echo "$cmd"
    
    echo ""
    read -p "Apply this configuration now? [y/N] " apply_choice
    if [[ "$apply_choice" =~ ^[Yy]$ ]]; then
        echo "Applying..."
        if eval "$cmd"; then
             echo -e "${GREEN}Configuration applied successfully.${NC}"
             # Update state from xrandr again to be sure?
             # parse_xrandr
        else
             echo -e "${RED}Failed to apply configuration.${NC}"
        fi
    fi
}

# ==============================================================================
# UI Logic
# ==============================================================================
print_header() {
    clear
    echo -e "${BOLD}Console Display Manager${NC}"
    echo "-----------------------"
}

print_status() {
    echo -e "\n${BOLD}Current Configuration:${NC}"
    printf "%-10s %-12s %-10s %-15s %-10s %s\n" "OUTPUT" "STATUS" "ENABLED" "MODE" "PRIMARY" "POS"
    echo "------------------------------------------------------------------"
    
    for out in "${OUTPUTS[@]}"; do
        local conn_str="${RED}disc${NC}"
        [[ "${STATE_CONNECTED[$out]}" == "1" ]] && conn_str="${GREEN}conn${NC}"
        
        local en_str="${RED}no${NC}"
        [[ "${STATE_ENABLED[$out]}" == "1" ]] && en_str="${GREEN}yes${NC}"
        
        local prim_str=""
        [[ "${STATE_PRIMARY[$out]}" == "1" ]] && prim_str="${YELLOW}*${NC}"
        
        local mode_str="${STATE_MODE[$out]}"
        local pos_str=""
        if [[ "${STATE_ENABLED[$out]}" == "1" ]]; then
            pos_str="${STATE_POS_X[$out]}x${STATE_POS_Y[$out]}"
        fi

        printf "%-10s %-20b %-20b %-15s %-10b %s\n" "$out" "$conn_str" "$en_str" "$mode_str" "$prim_str" "$pos_str"
    done
    echo ""
}

show_menu() {
    echo "1. Show displays (reload)"
    echo "2. Enable / Disable display"
    echo "3. Extend display"
    echo "4. Mirror display"
    echo "5. Set primary display"
    echo "6. Save layout"
    echo "0. Exit"
    echo -n "Select option: "
}

# ==============================================================================
# Main Loop
# ==============================================================================

# Parse initial state
parse_xrandr

while true; do
    print_header
    print_status
    show_menu
    read -r choice
    
    case $choice in
        1)
            parse_xrandr
            ;;
        2)
            action_enable_disable
            ;;
        3)
            action_extend
            read -p "Press Enter..."
             ;;
        4)
            action_mirror
            read -p "Press Enter..."
            ;;
        5)
            action_primary
            ;;
        6)
            save_layout
             read -p "Press Enter..."
            ;;
        0)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Not implemented yet."
            read -p "Press Enter to continue..."
            ;;
    esac
done
