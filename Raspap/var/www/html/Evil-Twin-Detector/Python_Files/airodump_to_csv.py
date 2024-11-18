import pandas as pd
import sys
import os

# Dynamically set BASE_DIR to the directory where the script is located
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Get the filename from the command line argument
filename = sys.argv[1]

# Construct the airodump output CSV file path
csv_file = os.path.join(BASE_DIR, "../Captures", f"{filename}_airodump.csv")

# Check if the file exists
if not os.path.isfile(csv_file):
    print(f"File not found: {csv_file}")
    sys.exit(1)

# Load the CSV file
df = pd.read_csv(csv_file)

# Find the index of the row containing 'Station MAC'
station_mac_index = df[df['BSSID'] == 'Station MAC'].index[0]

# Keep only the rows before 'Station MAC'
df_cleaned = df.iloc[:station_mac_index]

# Strip any leading/trailing whitespace from column names
df_cleaned.columns = df_cleaned.columns.str.strip()

# Save the cleaned DataFrame back to CSV
df_cleaned.to_csv(csv_file, index=False)

