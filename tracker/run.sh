#!/usr/bin/with-contenv bashio
# Define Variables
API_KEY=$(bashio::config 'api_key')
CONFIG_PROG=$(bashio::config 'assign_stations_program')
ROUTE_IDS=("red" "blue" "brn" "g" "org" "p" "pink" "y")
PERSIST_DIR="/data/position"
CTA_STATION_LIST="/data/ctastationlist.csv"
PROCESSOR_SCRIPT="/data/processor.py"
LIGHT_CONFIG_SCRIPT="/data/lightconfig.py"
HA_URL="${HA_URL:-http://supervisor/core/api}" 
# Define train line colors from config.yaml and EXPORT them as environment variables
export RED_COLOR=$(bashio::config 'red_line_color')
export PINK_COLOR=$(bashio::config 'pink_line_color')
export ORANGE_COLOR=$(bashio::config 'orange_line_color')
export YELLOW_COLOR=$(bashio::config 'yellow_line_color')
export GREEN_COLOR=$(bashio::config 'green_line_color')
export BLUE_COLOR=$(bashio::config 'blue_line_color')
export PURPLE_COLOR=$(bashio::config 'purple_line_color')
export BROWN_COLOR=$(bashio::config 'brown_line_color')

# Functions
fetch_route_data() {
    local ROUTE_ID="$1"
    local JSON_FILE="$PERSIST_DIR/$ROUTE_ID.json"

    local API_URL="http://lapi.transitchicago.com/api/1.0/ttpositions.aspx?key=$API_KEY&rt=$ROUTE_ID&outputType=JSON"

    # Make the request using curl and save the output
    CURL_STATUS=$(curl -sSL -o "$JSON_FILE" "$API_URL" -w "%{http_code}\n")
    
    HTTP_CODE=$(echo "$CURL_STATUS" | tail -n 1)

    if [ "$HTTP_CODE" -eq 200 ]; then
        : 
    else
        echo "Error: API request failed for Route $ROUTE_ID with HTTP status code $HTTP_CODE."
        echo "Request URL: $API_URL"
        
        if [ -f "$JSON_FILE" ]; then
            rm "$JSON_FILE"
            echo "Removed potentially erroneous file: $JSON_FILE"
        fi
    fi
}

cleanup() {
    echo "Cleaning up temporary file: ${TEMP_ACTIVE_IDS_FILE}" >&2 # Redirect log to stderr
    rm -f "$TEMP_ACTIVE_IDS_FILE"
}

# Install files to persistent storage.
cp -rv /files/* /data/

# If config variable set TRUE then run light configuration program
if [ "$CONFIG_PROG" == "true" ]; then
    python3 "$LIGHT_CONFIG_SCRIPT" \
        --station-list "$CTA_STATION_LIST" \
        --input-dir "$PERSIST_DIR" \
        --output-file "$JSON_FILE"
fi

echo "Starting recurring data fetch loop..."
while true; do
    echo "Starting CTA Route Position Fetcher"
    echo "--------------------------------------------------------"
    echo "Target Directory: $PERSIST_DIR"

    # Ensure the output directory exists once before the loop
    mkdir -p "$PERSIST_DIR"

    # Loop through the array and call the function for each route
    for ROUTE in "${ROUTE_IDS[@]}"; do
        fetch_route_data "$ROUTE"
    done

    echo "All routes processed. "
    echo "--------------------------------------------------------"
    python3 "$PROCESSOR_SCRIPT" \
        --station-list "$CTA_STATION_LIST" \
        --input-dir "$PERSIST_DIR" \
        --output-file "$JSON_FILE"

    if [ $? -eq 0 ]; then
        echo "--------------------------------------------------------"
        echo "Successfully completed processing. Output saved to $JSON_FILE"
    else
        echo "--------------------------------------------------------"
        echo "Error: Python script failed."
    fi

    python3 /data/light_control.py \
        --station-list "$CTA_STATION_LIST" \
        --input-dir "$PERSIST_DIR" \
        --output-file "$JSON_FILE"

    if [ $? -eq 0 ]; then
        echo "--------------------------------------------------------"
        echo "Successfully completed light control."
    else
        echo "--------------------------------------------------------"
        echo "Error: Light control script failed."
    fi

    # Wait for 60 seconds before running again
    sleep 60
done
