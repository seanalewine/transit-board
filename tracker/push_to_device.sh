#!/usr/bin/with-contenv bashio

# --- Configuration: Read from Add-on Config ---
LIGHT_BOARD_BASE=$(bashio::config 'light_board')
BRIGHTNESS=$(bashio::config 'brightness') 

# Configuration
JSON_FILE="/data/active_train_summary.json"
HA_URL="${HA_URL:-http://supervisor/core/api}" # Default for Add-ons

TEMP_ACTIVE_IDS_FILE=$(mktemp)

# --- Cleanup Function and Trap ---
cleanup() {
    echo "🧹 Cleaning up temporary file: ${TEMP_ACTIVE_IDS_FILE}" >&2 # Redirect log to stderr
    rm -f "$TEMP_ACTIVE_IDS_FILE"
}
# Trap ensures the cleanup function runs when the script exits (normally or via error)
trap cleanup EXIT

# --- Utility Functions ---

# Returns a space-separated string of IDs (e.g., "5 12 42")
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
        jq -r '.[] | select(.entity_id | startswith("light.esp_train_tracker_")) | select(.state == "on") | .entity_id' | \
        sed 's/light\.esp_train_tracker_//g' | \
        tr '\n' ' ')
        
    # Only the IDs are printed to stdout
    echo "$on_ids"
}

# Function to turn on a light with a specific color
set_light_color() {
    local sta_id=$1
    local color_rgb=$2
    local entity_id="light.esp_train_tracker_${sta_id}"

    # Normalize BRIGHTNESS: HA brightness_pct must be between 1 and 100. 
    local safe_brightness="${BRIGHTNESS}"
    if (( safe_brightness > 100 )); then
        safe_brightness=100
        echo "⚠️ Warning: Brightness value (${BRIGHTNESS}) is over 100. Capped at 100%." >&2
    fi

    echo "💡 Setting ${entity_id} to color: ${color_rgb}, and brightness: ${safe_brightness}%"

    # Prepare data payload for the Home Assistant API call
    IFS=',' read -r R G B <<< "$color_rgb"
    
    # Check if B is empty
    if [ -z "$B" ]; then
        echo "⚠️ Error parsing color string: ${color_rgb}. Expected R,G,B format." >&2
        return
    fi
    
    # Using 'brightness_pct'
    DATA="{\"entity_id\": \"${entity_id}\", \"rgb_color\": [${R}, ${G}, ${B}], \"brightness_pct\": ${safe_brightness}}"

    curl -s -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${DATA}" \
        "${HA_URL}/services/light/turn_on" > /dev/null
    sleep 0.25
}

# Function to turn off a light
turn_off_light() {
    local sta_id=$1
    local entity_id="light.esp_train_tracker_${sta_id}"
    
    # Added echo back for troubleshooting the 400 Bad Request error
    echo "⚫ Attempting to turn off ${entity_id}" >&2

    DATA="{\"entity_id\": \"${entity_id}\"}"
    
    # Redirect server response to /dev/null to clean up logs
    curl -s -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${DATA}" \
        "${HA_URL}/services/light/turn_off" > /dev/null
    
    sleep 0.25
}

# --- Main Logic ---

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

echo "Currently ON light IDs (before processing): ${PREVIOUSLY_ON_IDS_STRING}"
echo "------------------------------------------------"

echo "## Processing Active Trains and Collecting IDs"

# 2. PROCESS TRAINS AND TURN ON LIGHTS
jq -r '.trains[] | "\(.nextStaId) \(.output_color)"' "$JSON_FILE" | while IFS=' ' read -r sta_id color; do
    
    if [[ "$sta_id" =~ ^[0-9]+$ ]] && (( sta_id >= 0 && sta_id <= 255 )); then
        # Set the color for the active train light
        set_light_color "$sta_id" "$color"
        
        # Write the active ID to the file
        echo "$sta_id" >> "$TEMP_ACTIVE_IDS_FILE"
    else
        echo "⚠️ Warning: Invalid nextStaId found: ${sta_id}. Skipping." >&2
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