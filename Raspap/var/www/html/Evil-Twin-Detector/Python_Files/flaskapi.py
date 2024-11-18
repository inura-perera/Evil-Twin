from flask import Flask, jsonify, send_file
import os


app = Flask(__name__)

# Dynamically set BASE_DIR to the directory where the script is located
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

@app.route('/evil_twin_output', methods=['GET'])
def get_evil_twin_output():
    try:
        # Define the path to the JSON file using BASE_DIR
        filename = os.path.join(BASE_DIR, "../Captures", "flask_api.json")
        print(filename)  # Debug: Print the file path
        
        # Check if the file exists
        if not os.path.exists(filename):
            return jsonify({"error": "JSON file not found."}), 404

        # Send the JSON file as a response
        return send_file(filename, mimetype='application/json')

    except Exception as e:
        print(e)  # Debug: Print the exception
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
