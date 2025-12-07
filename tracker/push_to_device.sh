#!/usr/bin/with-contenv bashio

# --- Configuration: Replace the HA_URL Placeholders ---
# Read the base entity name from the Add-on's configuration (config.json)
# If your config.json has "light_board": "light.my_train_lights", 
# then LIGHT_BOARD_BASE will be "light.my_train_lights".
LIGHT_BOARD_BASE=$(bashio::config 'light_board')
BRIGHTNESS=$(bashio::config 'brightness')



# Configuration
JSON_FILE="/data/active_train_summary.json"
HA_URL="${HA_URL:-http://supervisor/core/api}" # Default for Add-ons

TEMP_ACTIVE_IDS_FILE=$(mktemp)

# --- Cleanup Function and Trap ---
cleanup() {
    echo "🧹 Cleaning up temporary file: ${TEMP_ACTIVE_IDS_FILE}"
    rm -f "$TEMP_ACTIVE_IDS_FILE"
}
# Trap ensures the cleanup function runs when the script exits (normally or via error)
trap cleanup EXIT

# --- Utility Functions ---

# Returns a space-separated string of IDs (e.g., "5 12 42")
get_on_lights() {
    echo "Fetching current state of all light entities..."
    
    # Call the Home Assistant API to get all states
    local states_json
    states_json=$(curl -s -X GET \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        "${HA_URL}/states")

    # Use jq to filter for 'light.esp_train_tracker_' entities that are 'on'.
    # 1. Selects the entity_id
    # 2. Pipes the entity_id to grep and sed for robust numerical extraction.
    local on_ids
    on_ids=$(echo "$states_json" | \
        jq -r '.[] | select(.entity_id | startswith("light.esp_train_tracker_")) | select(.state == "on") | .entity_id' | \
        sed 's/light\.esp_train_tracker_//g' | \
        tr '\n' ' ')
        
    echo "$on_ids"
}

# Function to turn on a light with a specific color
set_light_color() {
    local sta_id=$1
    local color_rgb=$2
    local entity_id="light.esp_train_tracker_${sta_id}"

    echo "💡 Setting ${entity_id} to color: ${color_rgb}, and brightness: ${BRIGHTNESS}%"

    # Prepare data payload for the Home Assistant API call

    IFS=',' read -r R G B <<< "$color_rgb"
    
    # Check if B is empty, which means only R and G were read (e.g., "198, 12")
    if [ -z "$B" ]; then
        echo "⚠️ Error parsing color string: ${color_rgb}. Expected R,G,B format."
        return
    fi
    
    # Construct the JSON data (rest of your logic is here)
    DATA="{\"entity_id\": \"${entity_id}\", \"rgb_color\": [${R}, ${G}, ${B}], \"brightness\": ${BRIGHTNESS}}"

    curl -s -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${DATA}" \
        "${HA_URL}/services/light/turn_on"
    sleep 0.02
}

# Function to turn off a light
turn_off_light() {
    local sta_id=$1
    local entity_id="light.esp_train_tracker_${sta_id}"
    
    DATA="{\"entity_id\": \"${entity_id}\"}"
    
    curl -s -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${DATA}" \
        "${HA_URL}/services/light/turn_off"
    sleep 0.02
}

# --- Main Logic ---

echo "--- Starting Light Control Script ---"

# Check for required dependencies
if ! command -v jq &> /dev/null; then
    echo "❌ Error: 'jq' is not installed. Please install it in your Add-on environment."
    exit 1
fi

if [ -z "$SUPERVISOR_TOKEN" ]; then
    echo "❌ Error: SUPERVISOR_TOKEN environment variable is not set."
    exit 1
fi

if [ ! -f "$JSON_FILE" ]; then
    echo "❌ Error: JSON file not found at ${JSON_FILE}"
    exit 1
fi

# 1. READ CURRENT STATE
# Get a space-separated string of IDs of lights currently ON
PREVIOUSLY_ON_IDS_STRING=$(get_on_lights)

echo "Currently ON light IDs (before processing): ${PREVIOUSLY_ON_IDS_STRING}"
echo "------------------------------------------------"

echo "## Processing Active Trains and Collecting IDs"

# 2. PROCESS TRAINS AND TURN ON LIGHTS
# Use 'jq' and pipe to 'while read'
jq -r '.trains[] | "\(.nextStaId) \(.output_color)"' "$JSON_FILE" | while IFS=' ' read -r sta_id color; do
    
    if [[ "$sta_id" =~ ^[0-9]+$ ]] && (( sta_id >= 0 && sta_id <= 255 )); then
        # Set the color for the active train light
        set_light_color "$sta_id" "$color"
        
        # Write the active ID to the file
        echo "$sta_id" >> "$TEMP_ACTIVE_IDS_FILE"
    else
        echo "⚠️ Warning: Invalid nextStaId found: ${sta_id}. Skipping."
    fi
done

# 3. Read the IDs from the temporary file into the array
mapfile -t ACTIVE_LIGHT_IDS < "$TEMP_ACTIVE_IDS_FILE"

# Convert the array to a space-separated string for efficient checking
ACTIVE_IDS_STRING=" ${ACTIVE_LIGHT_IDS[*]} "

echo "--- Identifying and Turning Off Lights ---"

# 4. LOOP THROUGH PREVIOUSLY ON LIGHTS AND TURN OFF INACTIVES
# Loop through the IDs that were ON before the script ran
for i in $PREVIOUSLY_ON_IDS_STRING; do
    
    # Check if the current ID (i) is NOT present in the list of lights we just set (ACTIVE_IDS_STRING)
    if [[ ! "$ACTIVE_IDS_STRING" =~ " $i " ]]; then
        # The light was ON but was NOT activated by the train data, so turn it off
        turn_off_light "$i"
    fi
done

echo "--- Script Finished Successfully ---"