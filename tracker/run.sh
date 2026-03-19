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
BIDIRECTIONAL=$(bashio::config 'bidirectional')
TRAINS_PER_LINE=$(bashio::config 'trainsPerLine')
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
    # -m 30: Set maximum time to 30 seconds (prevents long timeouts)
    # -f: Fail silently on HTTP 4xx and 5xx errors
    CURL_STATUS=$(curl -sSL -m 30 -f -o "$JSON_FILE" "$API_URL" -w "%{http_code}\n" 2>/dev/null)
    
    # Extract the numerical status code (it's the last line printed by curl -w)
    HTTP_CODE=$(echo "$CURL_STATUS" | tail -n 1)

    if [ "$HTTP_CODE" -eq 200 ]; then
        echo "Successfully fetched data for Route $ROUTE_ID"
    else
        # Handle non-200 responses
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

correct_bidirectional() {
    local ROUTE_ID="$1"
    local JSON_FILE="$PERSIST_DIR/$ROUTE_ID.json"

    # Check if file exists
    if [[ ! -f "$JSON_FILE" ]]; then
        echo "Error: File $JSON_FILE does not exist."
        return 0
    elif [[ ! -s "$JSON_FILE" ]]; then
        echo "Warning: File $JSON_FILE is empty, skipping processing."
        return 0
    elif ! jq empty "$JSON_FILE" 2>/dev/null; then
        echo "Error: File $JSON_FILE contains invalid JSON."
        return 0
    fi

    # Check if the structure exists and has train data
    local has_train_data=$(jq -r '.ctatt.route[] | .train? | select(. != null)' "$JSON_FILE" 2>/dev/null | wc -l)
    
    if [[ $has_train_data -eq 0 ]]; then
        echo "Warning: No train data found in $JSON_FILE, skipping processing."
        return 0
    else
        # Apply transformation safely
        jq '.ctatt.route |= map(if has("train") then .train |= map(select(.trDr == "1")) else . end)' "$JSON_FILE" > "${JSON_FILE}.tmp" && \
        mv "${JSON_FILE}.tmp" "$JSON_FILE"
    fi
}



truncate_train_entries() {
    local ROUTE_ID="$1"
    local JSON_FILE="$PERSIST_DIR/$ROUTE_ID.json"

    # Check if file exists
    if [[ ! -f "$JSON_FILE" ]]; then
        echo "Error: File $JSON_FILE does not exist."
        return 0
    elif [[ ! -s "$JSON_FILE" ]]; then
        echo "Warning: File $JSON_FILE is empty, skipping processing."
        return 0
    elif ! jq empty "$JSON_FILE" 2>/dev/null; then
        echo "Error: File $JSON_FILE contains invalid JSON."
        return 0
    else

        # Use jq to truncate the train array to first few entries
        jq --argjson limit "$TRAINS_PER_LINE" '.ctatt.route[0].train |= .[:$limit]' "$JSON_FILE" > "${JSON_FILE}.tmp" && \
        mv "${JSON_FILE}.tmp" "$JSON_FILE"
    fi
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
    echo "Fetching current state of all light entities..." >&2 
    
    # Call the Home Assistant API to get all states
    local states_json
    states_json=$(curl -s -X GET \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        "${HA_URL}/states")

    # Use jq to filter entities and extract just the numerical IDs
    local on_ids
    on_ids=$(echo "$states_json" | \
        jq -r '.[] | select(.entity_id | startswith("'"$LIGHT_BOARD_BASE"'")) | select(.state == "on") | .entity_id' | \
        sed 's/light\.('"$LIGHT_BOARD_BASE"')//g')

    # Print the IDs to stderr for logging
    echo "$on_ids" >&2
    
    # Return the IDs as a space-separated string
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

    #echo "DEBUG: Attempting to turn off light for entity ID: $1" >&2

    response=$(curl -s -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"entity_id\": \"$1\"}" \
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

    #echo "DEBUG: Successfully turned off light for entity: $1" >&2
    sleep "${SLEEP_TIME:-0.02}"
}

board_refresh() {
    local -n arr1=$1
    local -n arr2=$2
    local -n arr3=$3
    
    actualoff=($(array_diff $3 $1))
    echo "Refreshing lights on the board now." >&2
    
    # Get the maximum length among all arrays
    local max_len=0
    local len1=${#arr1[@]}
    local len2=${#arr2[@]}
    local len3=${#arr3[@]}
    
    if [[ $len1 -gt $max_len ]]; then max_len=$len1; fi
    if [[ $len2 -gt $max_len ]]; then max_len=$len2; fi
    if [[ $len3 -gt $max_len ]]; then max_len=$len3; fi
    
    # Process each index
    for ((i=0; i<max_len; i++)); do
        # Set light color if arrays 1 and 2 have values at this index
        if [[ $i -lt $len1 ]] && [[ $i -lt $len2 ]]; then
            set_light_color "${arr1[i]}" "${arr2[i]}"
        fi
        
        # Turn off light if array 3 has a value at this index
        if [[ $i -lt $len3 ]]; then
            turn_off_light "${actualoff[i]}"
        fi
    done
}

array_diff() {
    local -n arr1=$1
    local -n arr2=$2
    
    local result=()
    
    # Iterate through each element in the first array
    for item in "${arr1[@]}"; do
        local found=false
        
        # Check if this item exists in the second array
        for compare_item in "${arr2[@]}"; do
            if [[ "$item" == "$compare_item" ]]; then
                found=true
                break
            fi
        done
        
        # If item not found in second array, add it to result
        if [[ "$found" == false ]]; then
            result+=("$item")
        fi
    done
    
    # Return the result by printing each element on a new line
    printf '%s\n' "${result[@]}"
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

    #Set trains to only one direction, defaults to '1' or Northbound
    if [ "$BIDIRECTIONAL" = "false" ]; then
        echo "Bidirectional is set to 'false' so only Northbound trains will display."
        for ROUTE in "${ROUTE_IDS[@]}"; do
            correct_bidirectional "$ROUTE"
        done
    fi

    # Check if there is a config limit set for trains per line then run function to reduce number of trains.
    if [ $TRAINS_PER_LINE != 0 ]; then
        echo "Trains per line limited to: $TRAINS_PER_LINE. Removing excess trains."
        for ROUTE in "${ROUTE_IDS[@]}"; do
            truncate_train_entries "$ROUTE"
        done
    fi

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

    TEMP_ACTIVE_IDS_FILE=$(mktemp)
    cleanup() {
        echo "Cleaning up temporary files..."
        if [[ -n "$TEMP_ACTIVE_IDS_FILE" && -f "$TEMP_ACTIVE_IDS_FILE" ]]; then
            rm -f "$TEMP_ACTIVE_IDS_FILE"
            echo "Removed temporary file: $TEMP_ACTIVE_IDS_FILE"
        fi
    }
trap cleanup EXIT

    echo "--- Starting Light Control Script ---"

    # Check for required dependencies (jq)
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is not installed. Please install it in your Add-on environment." >&2
        exit 1
    fi

    if [ ! -f "$JSON_FILE" ]; then
        echo "Error: JSON file not found at ${JSON_FILE}" >&2
        exit 1
    fi

    # 1. READ CURRENT STATE
    # This variable will now ONLY contain the space-separated light IDs.
    mapfile -t light_ids < <(get_on_lights)
    echo "Array size: ${#light_ids[@]}"
    echo "First ID: ${light_ids[0]}"

    echo "## Processing Active Trains and Collecting IDs"

    # 2. PROCESS TRAINS INTO ARRAYS
    sta_ids=()
    colors=()

    jq -r '.[] | .unifiedId + " " + .rgb' "$JSON_FILE" | while IFS=' ' read -r sta_id color; do
        
        if [[ "$sta_id" =~ ^[0-9]+$ ]] && (( sta_id >= 0 && sta_id <= 319 )); then
            # Store values in arrays instead of calling set_light_color
            sta_ids+=("$sta_id")
            colors+=("$color")
            
            # Write the active ID to the file
            #echo "$sta_id" >> "$TEMP_ACTIVE_IDS_FILE"
        else
            echo "Warning: Invalid unifiedId found: ${sta_id}. Skipping." >&2
        fi
    done


    board_refresh $sta_ids $colors $light_ids

    # 3. Read the IDs from the temporary file into the array
    #mapfile -t ACTIVE_LIGHT_IDS < "$TEMP_ACTIVE_IDS_FILE"
    #echo "Array size: ${#light_ids[@]}"
    #echo "First ID: ${light_ids[0]}"



    echo "--- Script Finished Successfully ---"
    sleep "${REFRESH_INTERVAL:-60}"
done