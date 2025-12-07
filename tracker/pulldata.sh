#!/usr/bin/with-contenv bashio

# A script to fetch CTA train/bus position data for multiple rail lines
# and save the data as separate JSON files.

# --- Configuration ---

# Define the list of CTA rail line IDs to process
ROUTE_IDS=("red" "blue" "brn" "g" "org" "p" "pink" "y")
OUTPUT_DIR="/data/position"

# Get API Key from the first command-line argument
API_KEY="$1"

# --- Function Definitions ---

# Function to fetch data for a single route ID
fetch_route_data() {
    local ROUTE_ID="$1"
    local KEY="$2"
    local OUTPUT_FILE="$OUTPUT_DIR/$ROUTE_ID.json"


    # 1. Construct the API URL
    local API_URL="http://lapi.transitchicago.com/api/1.0/ttpositions.aspx?key=$KEY&rt=$ROUTE_ID&outputType=JSON"

    # 2. Make the request using curl and save the output
    # -sSL: Silent, show errors, follow redirects
    # -o: Output the received data to the specified file, overwriting it if it already exists.
    # -w "%{http_code}": Prints the HTTP status code after the transfer
    CURL_STATUS=$(curl -sSL -o "$OUTPUT_FILE" "$API_URL" -w "%{http_code}\n")
    
    # Extract the numerical status code (it's the last line printed by curl -w)
    HTTP_CODE=$(echo "$CURL_STATUS" | tail -n 1)

    # 3. Check the HTTP response status code
    if [ "$HTTP_CODE" -eq 200 ]; then
        #echo "Success! Data saved to $OUTPUT_FILE (HTTP $HTTP_CODE)."
    else
        # Handle non-200 responses or network errors
        echo "Error: API request failed for Route $ROUTE_ID with HTTP status code $HTTP_CODE."
        echo "Request URL: $API_URL"
        
        # Remove the potentially incomplete/erroneous file
        if [ -f "$OUTPUT_FILE" ]; then
            rm "$OUTPUT_FILE"
            echo "Removed potentially erroneous file: $OUTPUT_FILE"
        fi
        # Continue to the next route even if one fails
    fi
}

# --- Main Logic ---

# Check if API Key is provided
if [ -z "$API_KEY" ]; then
    echo "Usage: $0 <API_KEY>"
    echo "Example: $0 your_api_key_here"
    exit 1
fi

echo "Starting CTA Route Position Fetcher"
echo "--------------------------------------------------------"
echo "Target Directory: $OUTPUT_DIR"

# Ensure the output directory exists once before the loop
echo "Checking directory structure..."
mkdir -p "$OUTPUT_DIR"

# Loop through the array and call the function for each route
for ROUTE in "${ROUTE_IDS[@]}"; do
    fetch_route_data "$ROUTE" "$API_KEY"
done

echo "All routes processed. "
echo "--------------------------------------------------------"

return