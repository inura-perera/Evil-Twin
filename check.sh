#!/bin/bash

# Name of the script to check
SCRIPT_NAME="wifi_captuer.sh"

# Check if the script is running
if pgrep -f "$SCRIPT_NAME" > /dev/null; then
   # Get the PIDs of the running instances
    PIDS=$(pgrep -f "$SCRIPT_NAME")
    echo "true"
    echo "Running PIDs: $PIDS"
else
    echo "false"
fi
