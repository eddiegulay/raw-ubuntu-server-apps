#!/bin/bash
# battery-watch.sh
# Continuously monitors battery levels and sends notifications
# Works with acpi and notify-send

# CONFIGURATION
LOW=15       # Battery percentage considered low
CRITICAL=5   # Battery percentage considered critical
INTERVAL=120 # Check interval in seconds

# Ensure acpi is installed
if ! command -v acpi &>/dev/null; then
    echo "Error: acpi is not installed. Please install it."
    exit 1
fi

# Infinite loop
while true; do
    STATUS=$(acpi -b)
    if [[ "$STATUS" != *"Discharging"* ]]; then
        sleep $INTERVAL
        continue
    fi

    # Extract battery percentage as a number
    PERCENT=$(echo "$STATUS" | grep -oP '\d+%' | tr -d '%')

    # Send notifications
    if (( PERCENT <= CRITICAL )); then
        notify-send -u critical "Battery Critical" "Battery at ${PERCENT}%. Plug in now."
    elif (( PERCENT <= LOW )); then
        notify-send -u normal "Battery Low" "Battery at ${PERCENT}%."
    fi

    sleep $INTERVAL
done
