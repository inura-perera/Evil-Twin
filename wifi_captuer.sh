#!/bin/bash

# PID file location
PIDFILE="/tmp/evil_twin/wifi_captuer_script.pid"

# Ensure the directory exists
#mkdir -p "$(dirname "$PIDFILE")"

# Check if the PID file exists and the process is still running
if [ -f "$PIDFILE" ] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    echo "Error: Script is already running (PID: $(cat $PIDFILE))"
    exit 1
fi

# Write current PID to the PID file
echo $$ > "$PIDFILE"

# Get the directory of the script
SCRIPT_DIR="$(dirname "$(realpath "$0")")"
CAPTURES_DIR="$SCRIPT_DIR/Captures"

# Create the Captures directory
mkdir -p "$CAPTURES_DIR"

# Function to select network interface
select_interface() {
    while true; do
        echo "Available network interfaces:"
        
        # Get and number the interfaces
        interfaces=($(ip -o link show | awk -F': ' '{print $2}'))
        for i in "${!interfaces[@]}"; do
            echo "$((i+1)). ${interfaces[$i]}"
        done
        echo " "

        echo "Enter the number corresponding to the interface you want to use:"
        read iface_number

        # Validate the user input
        if [[ "$iface_number" =~ ^[0-9]+$ ]] && [ "$iface_number" -ge 1 ] && [ "$iface_number" -le "${#interfaces[@]}" ]; then
            iface=${interfaces[$((iface_number-1))]}
            break
        else
            echo "Error: Invalid input. Please enter a valid number."
        fi
    done
}

# Function to generate a filename based on date and time
generate_filename() {
    filename=$(date +"%Y%m%d_%H%M%S")
    echo "File Name : $filename"
}

# Function to switch to monitor mode
switch_to_monitor_mode() {
    mode=$(iwconfig "$iface" | grep "Mode:Monitor")
    if [ -z "$mode" ]; then
        echo " "
        echo "$iface is not in monitor mode. Switching to monitor mode..."
        sudo ifconfig "$iface" down
        sudo iwconfig "$iface" mode monitor
        sudo ifconfig "$iface" up
    else
        echo " "
        echo "$iface is already in monitor mode. Skipping mode change."
        echo " "
    fi
}

# Function to start tcpdump and channel hopping
start_capture() {
    # Define the channels to hop between
    CHANNELS=(1 6 11)

    # Time to spend on each channel (in seconds)
    DWELL_TIME=10

    # Total capture time (in seconds)
    TOTAL_TIME=30

    # Calculate the number of iterations needed (channels x dwell time)
    MAX_ITERATIONS=$((TOTAL_TIME / DWELL_TIME))

    # Start tcpdump in the background and capture packets
    sudo tcpdump -i "$iface" -w "$CAPTURES_DIR/${filename}.pcap" &
    TCPDUMP_PID=$!
    # Wait for 2 seconds before starting channel hopping
    sleep 2

    # Start channel hopping with a counter
    iteration_count=0
    for ((i=0; i<$MAX_ITERATIONS; i++)); do
        for CHANNEL in "${CHANNELS[@]}"; do
            # Check if the total time limit has been reached
            if [[ $iteration_count -ge $MAX_ITERATIONS ]]; then
                break 2  # Exit both loops
            fi
           
            # Change to the specified channel
            sudo iwconfig "$iface" channel "$CHANNEL"
            echo "Switched to channel $CHANNEL"

            # Increment the iteration count
            iteration_count=$((iteration_count + 1))
           
            # Wait for the dwell time
            sleep $DWELL_TIME
        done
    done

    # Stop tcpdump after the capture is complete
    sudo kill "$TCPDUMP_PID"
}

# Function to process pcap and run airodump-ng followed by Python scripts
process_capture() {
    # Convert pcap file to JSON using tshark
    tshark -r "$CAPTURES_DIR/${filename}.pcap" -T json > "$CAPTURES_DIR/${filename}.json"
    echo " "
    echo "Capture complete. Files saved as ${filename}.pcap and ${filename}.json"

    # Define the wireless interface to use (replace 'wlan1' if necessary)
    INTERFACE="$iface"
    
    # Define the output file for airodump-ng (use the same filename)
    OUTPUT_FILE="$CAPTURES_DIR/${filename}_airodump"

    # Run airodump-ng in the background and save the process ID
    sudo airodump-ng --write-interval 1 --output-format csv --write "$OUTPUT_FILE" "$INTERFACE" &
    AIRODUMP_PID=$!

    # Sleep for 15 seconds (or modify as per your needs)
    sleep 15

    # Kill the airodump-ng process
    kill "$AIRODUMP_PID"

    # Wait for the process to terminate
    wait "$AIRODUMP_PID" 2>/dev/null

    echo "Airodump-ng capture saved as ${filename}_airodump.csv"
    
    # Rename the airodump file with the correct full path
    sudo mv "$CAPTURES_DIR/${filename}_airodump-01.csv" "$CAPTURES_DIR/${filename}_airodump.csv"
    
    # Call Python script with filename as argument
    sudo python3 "$SCRIPT_DIR/Python_Files/airodump_to_csv.py" "$filename"
    
    python3 "$SCRIPT_DIR/Python_Files/pcapercsv.py" "$filename"
    
    clear
    
    python3 "$SCRIPT_DIR/Python_Files/pickler.py" "$filename"
}

compress_archive() {
    # Remove the CSV file after processing
    sudo rm "$CAPTURES_DIR/${filename}.csv"

    # Create a tar.gz archive of all relevant files in the Captures directory
   sudo  tar -czf "$CAPTURES_DIR/${filename}.tar.gz" "$CAPTURES_DIR/${filename}.pcap" "$CAPTURES_DIR/${filename}.json" "$CAPTURES_DIR/${filename}_airodump.csv"

    # Remove all original files starting with ${filename} except for the tar.gz file
    sudo rm "$CAPTURES_DIR/${filename}.pcap" "$CAPTURES_DIR/${filename}.json" "$CAPTURES_DIR/${filename}_airodump.csv"
}




# Execute the script
select_interface
generate_filename
switch_to_monitor_mode
start_capture
process_capture
compress_archive

# Clean up the PID file after finishing
rm -f $PIDFILE