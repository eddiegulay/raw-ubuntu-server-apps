#!/bin/bash
# bt-audio-switch.sh
# Usage: ./bt-audio-switch.sh <MAC_ADDRESS> [profile]
# Example: ./bt-audio-switch.sh 88:0E:85:62:AB:ED a2dp-sink

DEVICE="$1"
PROFILE="${2:-a2dp-sink}"   # Default to A2DP
RETRIES=5
SLEEP_TIME=2
TIMEOUT=15

if [[ -z "$DEVICE" ]]; then
    echo "Usage: $0 <MAC_ADDRESS> [profile]"
    exit 1
fi

echo "=== Bluetooth Audio Switch ==="
echo "Device: $DEVICE"
echo "Profile: $PROFILE"

# Step 1: Pair, trust, and connect
echo "Pairing, trusting, and connecting..."
for i in $(seq 1 $RETRIES); do
    echo "Attempt $i/$RETRIES..."
    echo -e "power on\nagent on\ndefault-agent\npair $DEVICE\ntrust $DEVICE\nconnect $DEVICE" | bluetoothctl
    sleep $SLEEP_TIME

    # Step 2: Check for sink
    SINK=""
    ELAPSED=0
    while [[ -z "$SINK" && $ELAPSED -lt $TIMEOUT ]]; do
        SINK=$(pactl list short sinks | grep -i "$DEVICE" | awk '{print $2}')
        if [[ -n "$SINK" ]]; then
            break
        fi
        sleep 1
        ((ELAPSED++))
    done

    if [[ -n "$SINK" ]]; then
        echo "Sink detected: $SINK"
        break
    fi

    echo "Sink not found yet, retrying..."
done

if [[ -z "$SINK" ]]; then
    echo "Error: Sink for $DEVICE not found after $RETRIES attempts."
    exit 2
fi

# Step 3: Set profile
CARD="bluez_card.${DEVICE//:/_}"
echo "Setting profile $PROFILE on card $CARD..."
pactl set-card-profile "$CARD" "$PROFILE"

# Step 4: Unsuspend and activate the sink
echo "Unsuspending sink $SINK..."
pactl suspend-sink "$SINK" 0

# Step 5: Set as default sink
echo "Setting default sink..."
pactl set-default-sink "$SINK"

# Step 6: Move all audio streams
echo "Moving current audio streams..."
pactl list short sink-inputs | awk '{print $1}' | xargs -r -n1 pactl move-sink-input "$SINK"

echo "=== Done: Audio switched to $DEVICE ($SINK) ==="
