import pickle
import pandas as pd
import sys
import os
import json



def detect_evil_twin(filename):
    # Dynamically set BASE_DIR to the directory where the script is located
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

    # Use BASE_DIR to create paths
    csv_filepath = os.path.join(BASE_DIR, "../Captures", f"{filename}.csv")
    airodump_filepath = os.path.join(BASE_DIR, "../Captures", f"{filename}_airodump.csv")
    model_filepath = os.path.join(BASE_DIR, "../Model", "random_forest_model.pkl")

    # Load the pickle file
    with open(model_filepath, 'rb') as file:
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

        json_output = {'evil_twins': {}, 'normal': {}}

        # Check if there are any evil twins
        if evil_twin_bssids.size == 0:
            print("\nThere is NO Evil Twin in the Search.\n")
            json_output['status'] = 1  # All instances are normal
            # Consider all BSSIDs as normal if no evil twins
            normal_bssid_column = bssid_column.unique()
        else:
            print("\nBSSID of Evil Twin Instances:")
            json_output['status'] = 0  # Evil twins found
            for idx, bssid in enumerate(evil_twin_bssids, start=1):
                bssid_upper = bssid.upper()
                df_evil_twin_bssid = df_airodump[df_airodump['BSSID'] == bssid_upper]
                if not df_evil_twin_bssid.empty:
                    essid = df_evil_twin_bssid['ESSID'].values[0]
                else:
                    essid = "Unknown"
                print(f"BSSID: {bssid} | SSID: {essid}")
                # Create dynamic keys for evil twins
                json_output['evil_twins'][f'wifi{idx}'] = {'BSSID': bssid, 'SSID': essid}

            # Remove BSSIDs that are considered evil twins from normal BSSIDs
            normal_bssid_column = bssid_column[~bssid_column.isin(evil_twin_bssids)].unique()

        # Create dynamic keys for normal BSSIDs
        print("\nUnique BSSID Normal Instances:\n")
        for idx, bssid in enumerate(normal_bssid_column, start=1):
            bssid_upper = bssid.upper()
            df_normal_bssid = df_airodump[df_airodump['BSSID'] == bssid_upper]
            if not df_normal_bssid.empty:
                essid = df_normal_bssid['ESSID'].values[0]
            else:
                essid = "Unknown"
            print(f"BSSID: {bssid} | SSID: {essid}")

            # Create dynamic keys for normal BSSIDs
            json_output['normal'][f'wifi{idx}'] = {'BSSID': bssid, 'SSID': essid}

        return json_output

    except FileNotFoundError:
        return {"error": f"File '{csv_filepath}' or '{airodump_filepath}' not found."}
    except Exception as e:
        return {"error": str(e)}

def main():
    # Dynamically set BASE_DIR to the directory where the script is located
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    
    # Get the filename from the command-line arguments
    if len(sys.argv) != 2:
        print("Usage: python3 pickler.py <filename>")
        sys.exit(1)

    filename = sys.argv[1]
    result = detect_evil_twin(filename)

    # Write the result to a JSON file in the Captures directory
    json_output_filepath = os.path.join(BASE_DIR, "../Captures", "flask_api.json")
    with open(json_output_filepath, 'w') as json_file:
        json.dump(result, json_file, indent=4)

    print(f"\nOutput written to {json_output_filepath}")

if __name__ == "__main__":
    main()
