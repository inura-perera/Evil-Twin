import pickle
import pandas as pd
import sys
import os

def main():
    # Get the filename from the command-line arguments
    if len(sys.argv) != 2:
        print("Usage: python3 pickler.py <filename>")
        sys.exit(1)

    filename = sys.argv[1]
    csv_filepath = os.path.join("Captures", f"{filename}.csv")
    airodump_filepath = os.path.join("Captures", f"{filename}_airodump.csv")

    # Load the pickle file
    with open('Model/random_forest_model.pkl', 'rb') as file:
        model = pickle.load(file)

    try:
        # Load the CSV files
        df_main = pd.read_csv(csv_filepath)
        df_airodump = pd.read_csv(airodump_filepath)

        # Clean the 'airodump' DataFrame: strip whitespace and select 'BSSID' and 'ESSID' columns
        df_airodump['BSSID'] = df_airodump['BSSID'].str.strip()
        df_airodump['ESSID'] = df_airodump['ESSID'].str.strip()

        # Filter df_main based on type_subtype
        df_main = df_main[df_main['wlan.fc.type_subtype'].isin(['0x0008', '0x0005'])]

        # Convert hexadecimal strings to numeric (integer) values
        df_main['wlan.fc.type_subtype'] = df_main['wlan.fc.type_subtype'].apply(lambda x: int(x, 16))
        df_main['wlan.fc.ds'] = df_main['wlan.fc.ds'].apply(lambda x: int(x, 16))

        # Drop rows where 'bssid' value is 0
        df_main = df_main[df_main['bssid'] != '0']

        # Keep a copy of the 'bssid' column for later use
        bssid_column = df_main['bssid'].copy()

        # Drop the 'bssid' column from df_main for prediction
        df_main = df_main.drop(columns=['bssid'])

        # Predict the target variable using the model
        predictions = model.predict(df_main)

        # Identify the BSSIDs of evil twin instances
        evil_twin_bssids = bssid_column[predictions == 'evil_twin'].unique()

        # Check if there are any evil twins
        if evil_twin_bssids.size == 0:
            print("\nThere is NO Evil Twin in the Search.\n")
            # Consider all BSSIDs as normal if no evil twins
            normal_bssid_column = bssid_column.unique()
        else:
            print("\nBSSID of Evil Twin Instances:")
            for bssid in evil_twin_bssids:
                bssid_upper = bssid.upper()
                df_evil_twin_bssid = df_airodump[df_airodump['BSSID'] == bssid_upper]
                if not df_evil_twin_bssid.empty:
                    essid = df_evil_twin_bssid['ESSID'].values[0]
                else:
                    essid = "Unknown"
                print(f"BSSID: {bssid} | SSID: {essid}")

            # Remove BSSIDs that are considered evil twins from normal BSSIDs
            normal_bssid_column = bssid_column[~bssid_column.isin(evil_twin_bssids)].unique()

        # Merge df_airodump with normal BSSID to get corresponding ESSIDs
        df_normal = df_airodump[df_airodump['BSSID'].isin(normal_bssid_column)]

        print("\nUnique BSSID Normal Instances:\n")
        for bssid in normal_bssid_column:
            bssid_upper = bssid.upper()
            df_normal_bssid = df_airodump[df_airodump['BSSID'] == bssid_upper]
            if not df_normal_bssid.empty:
                essid = df_normal_bssid['ESSID'].values[0]
            else:
                essid = "Unknown"
            print(f"BSSID: {bssid} | SSID: {essid}")

    except FileNotFoundError:
        print(f"Error: File '{csv_filepath}' or '{airodump_filepath}' not found.")
    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
