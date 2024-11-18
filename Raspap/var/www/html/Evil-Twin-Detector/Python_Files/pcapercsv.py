import json
import pandas as pd
import sys
import os

def create_bssid_subsets(json_data):
    bssid_subsets = []
    
    for packet in json_data:
        try:
            frame_details = {
                "bssid": 0,
                "frame.time_delta": 0,
                "frame.time_delta_displayed": 0,
                "frame.time_relative": 0,
                "frame.len": 0,
                "frame.cap_len": 0,
                "radiotap.present.rate": 0,
                "radiotap.present.dbm_antsignal": 0,
                "radiotap.present.antenna": 0,
                "radiotap.present.rtap_ns": 0,
                "radiotap.present.ext": 0,
                "radiotap.datarate": 0,
                "radiotap.dbm_antsignal": 0,
                "wlan.fc.type_subtype": 0,
                "wlan.fc.type": 0,
                "wlan.fc.subtype": 0,
                "wlan.fc.ds": 0,
                "wlan.duration": 0,
                "wlan.frag": 0,
                "wlan.seq": 0,
                "wlan.ba.control.ackpolicy": 0,
                "wlan.qos.tid": 0,
                "wlan.qos.priority": 0,
                "data.len": 0
            }

            # Check if 'wlan.bssid' exists before accessing it
            if "_source" in packet and "layers" in packet["_source"] and "wlan" in packet["_source"]["layers"] and "wlan.bssid" in packet["_source"]["layers"]["wlan"]:
                frame_details["bssid"] = packet["_source"]["layers"]["wlan"]["wlan.bssid"]

            # Update dictionary with actual values if available
            frame_details["frame.time_delta"] = packet["_source"]["layers"]["frame"].get("frame.time_delta", 0)
            frame_details["frame.time_delta_displayed"] = packet["_source"]["layers"]["frame"].get("frame.time_delta_displayed", 0)
            frame_details["frame.time_relative"] = packet["_source"]["layers"]["frame"].get("frame.time_relative", 0)
            frame_details["frame.len"] = packet["_source"]["layers"]["frame"].get("frame.len", 0)
            frame_details["frame.cap_len"] = packet["_source"]["layers"]["frame"].get("frame.cap_len", 0)
            
            frame_details["radiotap.present.rate"] = packet["_source"]["layers"]["radiotap"]["radiotap.present"]["radiotap.present.word_tree"].get("radiotap.present.rate", 0)
            frame_details["radiotap.present.dbm_antsignal"] = packet["_source"]["layers"]["radiotap"]["radiotap.present"]["radiotap.present.word_tree"].get("radiotap.present.dbm_antsignal", 0)
            frame_details["radiotap.present.antenna"] = packet["_source"]["layers"]["radiotap"]["radiotap.present"]["radiotap.present.word_tree"].get("radiotap.present.antenna", 0)
            frame_details["radiotap.present.rtap_ns"] = packet["_source"]["layers"]["radiotap"]["radiotap.present"]["radiotap.present.word_tree"].get("radiotap.present.rtap_ns", 0)
            frame_details["radiotap.present.ext"] = packet["_source"]["layers"]["radiotap"]["radiotap.present"]["radiotap.present.word_tree"].get("radiotap.present.ext", 0)
            frame_details["radiotap.datarate"] = packet["_source"]["layers"]["radiotap"].get("radiotap.datarate", 0)
            frame_details["radiotap.dbm_antsignal"] = packet["_source"]["layers"]["radiotap"].get("radiotap.dbm_antsignal", 0)
            
            frame_details["wlan.fc.type_subtype"] = packet["_source"]["layers"]["wlan"].get("wlan.fc.type_subtype", 0)
            frame_details["wlan.fc.type"] = packet["_source"]["layers"]["wlan"]["wlan.fc_tree"].get("wlan.fc.type", 0)
            frame_details["wlan.fc.subtype"] = packet["_source"]["layers"]["wlan"]["wlan.fc_tree"].get("wlan.fc.subtype", 0)
            frame_details["wlan.fc.ds"] = packet["_source"]["layers"]["wlan"]["wlan.fc_tree"]["wlan.flags_tree"].get("wlan.fc.ds", 0)
            frame_details["wlan.duration"] = packet["_source"]["layers"]["wlan"].get("wlan.duration", 0)
            frame_details["wlan.frag"] = packet["_source"]["layers"]["wlan"].get("wlan.frag", 0)
            frame_details["wlan.seq"] = packet["_source"]["layers"]["wlan"].get("wlan.seq", 0)
            
            compressed_blockack = packet["_source"]["layers"]["wlan"].get("Compressed BlockAck Response", None)
            if compressed_blockack:
                frame_details["wlan.ba.control.ackpolicy"] = compressed_blockack.get("wlan.ba.control_tree", {}).get("wlan.ba.control.ackpolicy", 0)

            frame_details["wlan.qos.tid"] = packet["_source"]["layers"]["wlan"].get("wlan.qos_tree", {}).get("wlan.qos.tid", 0)
            frame_details["wlan.qos.priority"] = packet["_source"]["layers"]["wlan"].get("wlan.qos_tree", {}).get("wlan.qos.priority", 0)
            frame_details["data.len"] = packet["_source"]["layers"].get("data", {}).get("data.len", 0)
            
            bssid_subsets.append(frame_details)
                
        except KeyError as e:
            print(f"Error accessing packet details: {e}")
    
    return bssid_subsets




def main():
    # Dynamically set BASE_DIR to the directory where the script is located
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))
    
    # Get the JSON filename from command-line argument
    if len(sys.argv) != 2:
        print("Usage: python3 pcapercsv.py <filename>")
        sys.exit(1)
    
    json_filename = sys.argv[1]
    json_filepath = os.path.join(BASE_DIR, "../Captures", json_filename + '.json')
    
    try:
        with open(json_filepath, 'r') as f:
            data = json.load(f)
        
        bssid_subsets = create_bssid_subsets(data)
        df = pd.DataFrame(bssid_subsets)
        
        # Ensure Captures directory exists in BASE_DIR
        captures_dir = os.path.join(BASE_DIR, "../Captures")
        os.makedirs(captures_dir, exist_ok=True)
        
        csv_filename = os.path.join(captures_dir, json_filename + '.csv')
        df.to_csv(csv_filename, index=False)
    
    except FileNotFoundError:
        print(f"Error: File '{json_filepath}' not found.")

if __name__ == "__main__":
    main()


