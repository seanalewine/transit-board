#!/usr/bin/with-contenv bashio
#Define Variables
API_KEY=$(bashio::config 'api_key')
CONFIG_PROG=$(bashio::config 'assign_stations_program')
ROUTE_IDS=("red" "blue" "brn" "g" "org" "p" "pink" "y")
PERSIST_DIR="/data/position"
CTA_STATION_LIST="/data/ctastationlist.csv"
PROCESSOR_SCRIPT="/data/processor.py"
LIGHT_BOARD_BASEPRE=$(bashio::config 'light_board')
LIGHT_BOARD_BASE="${LIGHT_BOARD_BASEPRE}_"
BRIGHTNESS=$(bashio::config 'brightness')
REFRESH_INTERVAL=$(bashio::config 'data_refresh_interval_sec')
SLEEP_TIME=$(bashio::config 'indiv_light_refresh_delay_sec')
JSON_FILE="/data/active_train_summary.json"
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

#Functions
fetch_route_data() {
    local ROUTE_ID="$1"
    local JSON_FILE="$PERSIST_DIR/$ROUTE_ID.json"

    local API_URL="http://lapi.transitchicago.com/api/1.0/ttpositions.aspx?key=$API_KEY&rt=$ROUTE_ID&outputType=JSON"

    # 2. Make the request using curl and save the output
    # -sSL: Silent, show errors, follow redirects
    # -o: Output the received data to the specified file, overwriting it if it already exists.
    # -w "%{http_code}": Prints the HTTP status code after the transfer
    CURL_STATUS=$(curl -sSL -o "$JSON_FILE" "$API_URL" -w "%{http_code}\n")
    
    # Extract the numerical status code (it's the last line printed by curl -w)
    HTTP_CODE=$(echo "$CURL_STATUS" | tail -n 1)

if [ "$HTTP_CODE" -eq 200 ]; then
    : 
else
    # Handle non-200 responses or network errors (logging the failure)
    echo "Error: API request failed for Route $ROUTE_ID with HTTP status code $HTTP_CODE."
    echo "Request URL: $API_URL"
    
    # Remove the potentially incomplete/erroneous file
    if [ -f "$JSON_FILE" ]; then
        rm "$JSON_FILE"
        echo "Removed potentially erroneous file: $JSON_FILE"
    fi
    # Continue to the next route even if one fails
fi
}

cleanup() {
    echo "🧹 Cleaning up temporary file: ${TEMP_ACTIVE_IDS_FILE}" >&2 # Redirect log to stderr
    rm -f "$TEMP_ACTIVE_IDS_FILE"
}


#Install files to persistant storage.
cp -rv /files/* /data/

#If config variable set TRUE then run light configuration program
if [ "$CONFIG_PROG" == "true" ]; then
    python3 "/data/lightconfig.py" \
        --station-list "$CTA_STATION_LIST" \
        --input-dir "$PERSIST_DIR" \
        --output-file "$JSON_FILE"
fi

get_on_lights() {
    # 🌟 FIXED: Redirecting log messages to stderr (>&2) so they aren't captured by the variable assignment
    echo "Fetching current state of all light entities..." >&2 
    
    # Call the Home Assistant API to get all states
    local states_json
    states_json=$(curl -s -X GET \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        "${HA_URL}/states")

    # Use jq to filter entities and sed to safely extract the numerical ID
    local on_ids
    on_ids=$(echo "$states_json" | \
        jq -r '.[] | select(.entity_id | startswith("'"$LIGHT_BOARD_BASE"'")) | select(.state == "on") | .entity_id' | \
        sed 's/light\.('"$LIGHT_BOARD_BASE"')//g' | \
        tr '\n' ' ')
        
    # Only the IDs are printed to stdout
    echo "$on_ids"
}

set_light_color() {
    local sta_id=$1
    local color_rgb=$2
    local entity_id="${LIGHT_BOARD_BASE}${sta_id}"

    # Normalize BRIGHTNESS
    local safe_brightness="${BRIGHTNESS}"
    if (( safe_brightness > 100 )); then
        safe_brightness=100
        echo "Warning: Brightness capped at 100%" >&2
    fi

    IFS=',' read -r R G B <<< "$color_rgb"
    if [ -z "$B" ]; then
        echo "Error parsing color string: ${color_rgb}" >&2
        return
    fi

    DATA="{\"entity_id\": \"${entity_id}\", \"rgb_color\": [${R}, ${G}, ${B}], \"brightness_pct\": ${safe_brightness}}"

    response=$(curl -s -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${DATA}" \
        "${HA_URL}/services/light/turn_on")

    sleep "${SLEEP_TIME:-0.02}"
}

turn_off_light() {

    # Validate input parameters
    if [[ -z "$1" ]]; then
        echo "ERROR: Station ID is required" >&2
        return 1
    fi

    echo "DEBUG: Attempting to turn off light for entity ID: $1" >&2

    response=$(curl -s -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"entity_id\": \"${$1}\"}" \
        "${HA_URL}/services/light/turn_off")

    # Check if curl command was successful
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to execute curl request for station ID: $1" >&2
        return 1
    fi

    # Check response status
    if [[ "$response" == *"400"* ]] || [[ "$response" == *"Bad Request"* ]]; then
        echo "ERROR: Bad Request returned from Home Assistant - likely invalid entity ID or malformed request" >&2
        echo "DEBUG: Response was: $response" >&2
        return 1
    fi

    # Check if response contains error information
    if [[ "$response" == *"error"* ]] || [[ "$response" == *"Error"* ]]; then
        echo "WARNING: Response may contain errors: $response" >&2
    fi

    echo "DEBUG: Successfully turned off light for entity: $1" >&2
    sleep "${SLEEP_TIME:-0.02}"
}



echo "Starting recurring data fetch loop..."
while true; do
    # Run the data refresh script
    # The 'source' command is used to run the script in the current environment

    echo "Starting CTA Route Position Fetcher"
    echo "--------------------------------------------------------"
    echo "Target Directory: $PERSIST_DIR"

    # Ensure the output directory exists once before the loop
    echo "Checking directory structure..."
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

    #head -n 20 /data/active_train_summary.json

    TEMP_ACTIVE_IDS_FILE=$(mktemp)
    trap cleanup EXIT
    echo "--- Starting Light Control Script ---"

    # Check for required dependencies (jq)
    if ! command -v jq &> /dev/null; then
        echo "❌ Error: 'jq' is not installed. Please install it in your Add-on environment." >&2
        exit 1
    fi

    if [ -z "$SUPERVISOR_TOKEN" ]; then
        echo "❌ Error: SUPERVISOR_TOKEN environment variable is not set." >&2
        exit 1
    fi

    if [ ! -f "$JSON_FILE" ]; then
        echo "❌ Error: JSON file not found at ${JSON_FILE}" >&2
        exit 1
    fi

    # 1. READ CURRENT STATE
    # This variable will now ONLY contain the space-separated light IDs.
    PREVIOUSLY_ON_IDS_STRING=$(get_on_lights)

    echo "## Processing Active Trains and Collecting IDs"

    # 2. PROCESS TRAINS AND TURN ON LIGHTS
    jq -r '.[] | "\(.unifiedId) \(.rgb)"' "$JSON_FILE" | while IFS=' ' read -r sta_id color; do
        
        if [[ "$sta_id" =~ ^[0-9]+$ ]] && (( sta_id >= 0 && sta_id <= 255 )); then
            # Set the color for the active train light
            set_light_color "$sta_id" "$color"
            
            # Write the active ID to the file
            echo "$sta_id" >> "$TEMP_ACTIVE_IDS_FILE"
        else
            echo "⚠️ Warning: Invalid unifiedId found: ${sta_id}. Skipping." >&2
        fi
    done

    # 3. Read the IDs from the temporary file into the array
    mapfile -t ACTIVE_LIGHT_IDS < "$TEMP_ACTIVE_IDS_FILE"

    # Convert the array to a space-separated string for efficient checking
    ACTIVE_IDS_STRING=" ${ACTIVE_LIGHT_IDS[*]} "

    echo "--- Identifying and Turning Off Lights ---"

    # 4. LOOP THROUGH PREVIOUSLY ON LIGHTS AND TURN OFF INACTIVES
    for i in $PREVIOUSLY_ON_IDS_STRING; do
        
        # Sanity check to ensure $i is not empty or malformed
        if [[ -z "$i" ]]; then
            continue 
        fi

        # Check if the current ID (i) is NOT present in the list of lights we just set (ACTIVE_IDS_STRING)
        if [[ ! "$ACTIVE_IDS_STRING" =~ " $i " ]]; then
            # The light was ON but was NOT activated by the train data, so turn it off
            turn_off_light "$i"
        fi
    done

    echo "--- Script Finished Successfully ---"
    sleep "${REFRESH_INTERVAL:-60}"
done