#!/bin/bash

# Directory where the files are located (you can modify this path as needed)
directory="Captures"

# Find all .json and .pcap files in the directory, sorted by modification time (oldest first)
json_files=($(ls -1t $directory/*.json 2>/dev/null))
pcap_files=($(ls -1t $directory/*.pcap 2>/dev/null))

# Function to delete the oldest file
delete_oldest_files() {
    local file_type=$1
    local files=("${!2}")
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "No $file_type files to delete."
        return 1
    elif [ ${#files[@]} -eq 1 ]; then
        echo "Only one $file_type file found. Not deleting any files."
        return 1
    else
        oldest_file=${files[-1]}
        echo "Deleting the oldest $file_type file: $oldest_file"
        rm "$oldest_file"
    fi
    return 0
}

# Delete the oldest JSON file
delete_oldest_files "JSON" json_files[@] || exit 0

# Delete the oldest PCAP file
delete_oldest_files "PCAP" pcap_files[@] || exit 0

echo "Oldest files deleted successfully."
