#!/bin/bash
set -e

# PID file location
PIDFILE="/tmp/evil_twin/wifi_captuer_script.pid"

# Ensure the directory exists
mkdir -p "$(dirname "$PIDFILE")"

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
echo "Creating Captures directory: $CAPTURES_DIR..."
mkdir -p "$CAPTURES_DIR"
echo "Captures directory created."

# Function to check for essential tools
check_tools() {
    echo "Checking for essential tools..."
    tools=("ip" "iw" "tcpdump" "tshark" "airodump-ng" "python3")
    missing_tools=0
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            echo "Error: $tool is not installed. Please install it to continue." >&2
            missing_tools=$((missing_tools + 1))
        fi
    done

    if [ "$missing_tools" -gt 0 ]; then
        exit 1
    fi
    echo "Essential tools check complete."
}

# Call the function to check for essential tools
check_tools

# Function to check for Python dependencies
check_python_dependencies() {
    echo "Checking Python dependencies (pandas, scikit-learn)..."
    # The actual check is done by python3 -c, which will print its own errors if any.
    # set -e will cause the script to exit if python3 returns a non-zero status.
    if ! python3 -c "import sys; import pandas; import sklearn" &> /dev/null; then
        echo "Error: Critical Python dependencies (pandas, scikit-learn) are missing." >&2
        echo "Required Python libraries (pandas, scikit-learn) may not be installed." >&2
        echo "Please try installing them, for example: pip install pandas scikit-learn" >&2
        echo "If you are using a virtual environment, ensure it is activated and the libraries are installed within it." >&2
        exit 1
    # No need for an else here, if it passes, the script continues.
    # The previous echo "Python dependencies (pandas, scikit-learn) are present." is removed for brevity
    # as success is implied by continuation.
    fi
    echo "Python dependencies check complete."
}

# Call the function to check for Python dependencies
check_python_dependencies

# Function to select network interface
select_interface() {
    echo "Starting network interface selection..."
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
            echo "Selected interface: $iface"
            break
        else
            echo "Error: Invalid input. Please enter a valid number."
        fi
    done
    echo "Network interface selection complete."
}

# Function to generate a filename based on date and time
generate_filename() {
    echo "Generating filename..."
    filename=$(date +"%Y%m%d_%H%M%S")
    echo "Generated Filename: $filename"
}

# Function to switch to monitor mode
switch_to_monitor_mode() {
    echo "Preparing to switch $iface to monitor mode..."
    echo "Checking current mode for $iface..."
    if ! iw dev "$iface" info | grep -q "type monitor"; then
        echo "$iface is not in monitor mode. Attempting to switch..."
        sudo ip link set "$iface" down
        echo "$iface link down."
        sudo iw dev "$iface" set type monitor
        echo "$iface mode set to monitor."
        sudo ip link set "$iface" up
        echo "$iface link up."
        # Add a small delay and re-check to ensure mode is set
        echo "Pausing for 1 second to allow mode to stabilize..."
        sleep 1
        if ! iw dev "$iface" info | grep -q "type monitor"; then
            echo "Error: Failed to set $iface to monitor mode after attempt." >&2
            exit 1
        fi
        echo "$iface successfully switched to monitor mode."
    else
        echo "$iface is already in monitor mode. Skipping mode change."
    fi
}

# Function to start tcpdump and channel hopping
start_capture() {
    echo "Starting packet capture on $iface..."
    # Define the channels to hop between
    CHANNELS=(1 6 11)

    # Time to spend on each channel (in seconds)
    DWELL_TIME=10

    # Total capture time (in seconds)
    TOTAL_TIME=30

    # Calculate the number of iterations needed (channels x dwell time)
    MAX_ITERATIONS=$((TOTAL_TIME / DWELL_TIME))

    echo "Launching tcpdump..."
    # Start tcpdump in the background and capture packets
    sudo tcpdump -i "$iface" -w "$CAPTURES_DIR/${filename}.pcap" &
    TCPDUMP_PID=$!
    echo "tcpdump started with PID $TCPDUMP_PID. Waiting 2 seconds for it to initialize..."
    # Wait for 2 seconds before starting channel hopping
    sleep 2

    echo "Starting channel hopping for $TOTAL_TIME seconds (Dwell: $DWELL_TIME s/channel, Channels: ${CHANNELS[*]})..."
    # Start channel hopping with a counter
    iteration_count=0
    for ((i=0; i<$MAX_ITERATIONS; i++)); do
        for CHANNEL in "${CHANNELS[@]}"; do
            # Check if the total time limit has been reached
            if [[ $iteration_count -ge $MAX_ITERATIONS ]]; then
                echo "Total capture time reached. Stopping channel hopping."
                break 2  # Exit both loops
            fi
           
            # Change to the specified channel
            echo "Switching $iface to channel $CHANNEL..."
            sudo iwconfig "$iface" channel "$CHANNEL"
            echo "$iface switched to channel $CHANNEL."

            # Increment the iteration count
            iteration_count=$((iteration_count + 1))
           
            echo "Dwelling on channel $CHANNEL for $DWELL_TIME seconds..."
            sleep $DWELL_TIME
        done
    done
    echo "Channel hopping complete."

    echo "Stopping tcpdump (PID: $TCPDUMP_PID)..."
    # Stop tcpdump after the capture is complete
    sudo kill "$TCPDUMP_PID"
    echo "tcpdump stopped."
    echo "Packet capture complete."
}

# Function to process pcap and run airodump-ng followed by Python scripts
process_capture() {
    echo "Processing captured data for $filename..."
    
    echo "Converting pcap to json with tshark..."
    tshark -r "$CAPTURES_DIR/${filename}.pcap" -T json > "$CAPTURES_DIR/${filename}.json"
    echo "tshark conversion complete. Output: $CAPTURES_DIR/${filename}.json"

    # Define the wireless interface to use (replace 'wlan1' if necessary)
    INTERFACE="$iface" # Already selected, just for clarity
    
    # Define the output file for airodump-ng (use the same filename)
    OUTPUT_FILE="$CAPTURES_DIR/${filename}_airodump"

    echo "Starting airodump-ng..."
    # Run airodump-ng in the background and save the process ID
    sudo airodump-ng --write-interval 1 --output-format csv --write "$OUTPUT_FILE" "$INTERFACE" &
    AIRODUMP_PID=$!
    echo "airodump-ng started with PID $AIRODUMP_PID. Capturing for 15 seconds..."

    # Sleep for 15 seconds (or modify as per your needs)
    sleep 15

    echo "Stopping airodump-ng (PID: $AIRODUMP_PID)..."
    # Kill the airodump-ng process
    # Adding 2>/dev/null to suppress "No such process" if it already exited, set -e will handle other kill errors.
    kill "$AIRODUMP_PID" 2>/dev/null || echo "airodump-ng process (PID: $AIRODUMP_PID) already stopped or not found."
    
    echo "Waiting for airodump-ng to clean up..."
    # Wait for the process to terminate, suppress errors if already gone
    wait "$AIRODUMP_PID" 2>/dev/null || echo "airodump-ng process (PID: $AIRODUMP_PID) was not waited on (already exited)."
    echo "airodump-ng finished."

    # It's possible airodump-ng didn't create the file if it ran for too short a time or no APs were found.
    # Check for the file before moving.
    AIRODUMP_CSV_TEMP="${OUTPUT_FILE}-01.csv"
    AIRODUMP_CSV_FINAL="$CAPTURES_DIR/${filename}_airodump.csv"

    if [ -f "$AIRODUMP_CSV_TEMP" ]; then
        echo "Renaming airodump-ng output file from $AIRODUMP_CSV_TEMP to $AIRODUMP_CSV_FINAL..."
        sudo mv "$AIRODUMP_CSV_TEMP" "$AIRODUMP_CSV_FINAL"
        echo "Airodump-ng capture saved as $AIRODUMP_CSV_FINAL"
    else
        echo "Warning: Expected airodump-ng output file $AIRODUMP_CSV_TEMP not found. Skipping rename. This might indicate an issue with airodump-ng capture."
        # Creating an empty file so downstream Python scripts don't fail on file not found,
        # though they should ideally handle it.
        touch "$AIRODUMP_CSV_FINAL"
        echo "Created empty $AIRODUMP_CSV_FINAL to prevent downstream errors."
    fi
    
    echo "Running Python_Files/airodump_to_csv.py..."
    sudo python3 "$SCRIPT_DIR/Python_Files/airodump_to_csv.py" "$filename"
    echo "Python_Files/airodump_to_csv.py finished."
    
    echo "Running Python_Files/pcapercsv.py..."
    python3 "$SCRIPT_DIR/Python_Files/pcapercsv.py" "$filename"
    echo "Python_Files/pcapercsv.py finished."
    
    echo "Running Python_Files/pickler.py..."
    python3 "$SCRIPT_DIR/Python_Files/pickler.py" "$filename"
    echo "Python_Files/pickler.py finished."
    echo "Data processing complete."
}

compress_archive() {
    echo "Compressing and archiving files for $filename..."
    # Remove the CSV file after processing
    echo "Removing intermediate CSV file: $CAPTURES_DIR/${filename}.csv..."
    sudo rm "$CAPTURES_DIR/${filename}.csv"
    echo "Intermediate CSV file removed."

    ARCHIVE_FILE="$CAPTURES_DIR/${filename}.tar.gz"
    echo "Creating tar.gz archive: $ARCHIVE_FILE..."
    # Create a tar.gz archive of all relevant files in the Captures directory
   sudo  tar -czf "$ARCHIVE_FILE" "$CAPTURES_DIR/${filename}.pcap" "$CAPTURES_DIR/${filename}.json" "$CAPTURES_DIR/${filename}_airodump.csv" "$CAPTURES_DIR/${filename}_analysis_result.json"
    echo "Archive created: $ARCHIVE_FILE"

    echo "Removing original files after archiving..."
    # Remove all original files starting with ${filename} except for the tar.gz file
    sudo rm "$CAPTURES_DIR/${filename}.pcap" "$CAPTURES_DIR/${filename}.json" "$CAPTURES_DIR/${filename}_airodump.csv" "$CAPTURES_DIR/${filename}_analysis_result.json"
    echo "Original files removed."
    echo "Compression and archiving complete."
}




# Execute the script
echo "Executing script: wifi_captuer.sh"

echo "Step 1: Selecting network interface..."
select_interface
echo "Network interface selection completed."

echo "Step 2: Generating filename..."
generate_filename
echo "Filename generation completed: $filename"

echo "Step 3: Switching interface to monitor mode..."
switch_to_monitor_mode
echo "Monitor mode setup completed for $iface."

echo "Step 4: Starting packet capture..."
start_capture
echo "Packet capture finished."

echo "Step 5: Processing captured data..."
process_capture
echo "Data processing finished."

echo "Step 6: Compressing and archiving results..."
compress_archive
echo "Archiving finished."

# Clean up the PID file after finishing
echo "Cleaning up PID file: $PIDFILE..."
rm -f $PIDFILE
echo "PID file removed."

echo "Script execution finished successfully."