#!/bin/bash
# bt-connect.sh
# Usage:
#   bt-connect.sh -s <shortcut> [profile]
# Example:
#   bt-connect.sh -s q20i
#   bt-connect.sh -s q20i headset-head-unit

declare -A DEVICES
DEVICES=(
    [q20i]="88:0E:85:62:AB:ED"
    [earbuds]="XX:XX:XX:XX:XX:XX"
    # add more shortcuts here
)

# parse args
while getopts "s:" opt; do
    case $opt in
        s) SHORTCUT="$OPTARG" ;;
        *) echo "Usage: $0 -s <shortcut> [profile]"; exit 1 ;;
    esac
done
shift $((OPTIND-1))

PROFILE="${1:-a2dp-sink}"

if [[ -z "$SHORTCUT" || -z "${DEVICES[$SHORTCUT]}" ]]; then
    echo "Unknown shortcut: $SHORTCUT"
    echo "Available shortcuts: ${!DEVICES[@]}"
    exit 1
fi

DEVICE="${DEVICES[$SHORTCUT]}"

echo "Connecting $SHORTCUT ($DEVICE) with profile $PROFILE..."

# --- same connection logic as before ---
RETRIES=5
SLEEP_TIME=2
TIMEOUT=15

for i in $(seq 1 $RETRIES); do
    echo "Attempt $i/$RETRIES..."
    echo -e "power on\nagent on\ndefault-agent\nconnect $DEVICE" | bluetoothctl
    sleep $SLEEP_TIME

    SINK=""
    ELAPSED=0
    while [[ -z "$SINK" && $ELAPSED -lt $TIMEOUT ]]; do
        SINK=$(pactl list short sinks | grep -i "$DEVICE" | awk '{print $2}')
        [[ -n "$SINK" ]] && break
        sleep 1
        ((ELAPSED++))
    done

    [[ -n "$SINK" ]] && break
done

if [[ -z "$SINK" ]]; then
    echo "Error: Sink for $DEVICE not found."
    exit 2
fi

CARD="bluez_card.${DEVICE//:/_}"
pactl set-card-profile "$CARD" "$PROFILE"
pactl suspend-sink "$SINK" 0
pactl set-default-sink "$SINK"
pactl list short sink-inputs | awk '{print $1}' | xargs -r -n1 pactl move-sink-input "$SINK"

echo "Audio switched to $SHORTCUT ($SINK)."
