@app.get("/evil_twin", tags=["Evil Twin"])
async def get_evil_twin(api_key: APIKey = Depends(auth.get_api_key)):
    try:
        # Assuming your Flask API runs locally on port 5000 and has an endpoint /evil_twin_output
        response = requests.get("http://127.0.0.1:5000/evil_twin_output")
        if response.status_code == 200:
            return response.json()  # Return the evil twin output as JSON
        else:
            raise HTTPException(status_code=response.status_code, detail="Failed to fetch evil twin data")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))