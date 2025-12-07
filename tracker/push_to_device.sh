#!/usr/bin/with-contenv bashio

# --- Configuration: Replace the HA_URL Placeholders ---
# Read the base entity name from the Add-on's configuration (config.json)
# If your config.json has "light_board": "light.my_train_lights", 
# then LIGHT_BOARD_BASE will be "light.my_train_lights".
LIGHT_BOARD_BASE=$(bashio::config 'light_board')



# Configuration
JSON_FILE="/data/active_train_summary.json"
HA_URL="${HA_URL:-http://supervisor/core/api}" # Default for Add-ons

# --- Utility Functions ---

# Function to turn on a light with a specific color
set_light_color() {
    local sta_id=$1
    local color_rgb=$2
    local entity_id="light.esp_train_tracker_${sta_id}"

    echo "💡 Setting ${entity_id} to color: ${color_rgb}"

    # Prepare data payload for the Home Assistant API call
    
    IFS=',' read -r R G B <<< "$color_rgb"
    
    # Check if B is empty, which means only R and G were read (e.g., "198, 12")
    if [ -z "$B" ]; then
        echo "⚠️ Error parsing color string: ${color_rgb}. Expected R,G,B format."
        return
    fi
    
    # Construct the JSON data (rest of your logic is here)
    DATA="{\"entity_id\": \"${entity_id}\", \"rgb_color\": [${R}, ${G}, ${B}], \"brightness_pct\": 100}"

    curl -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${DATA}" \
        "${HA_URL}/services/light/turn_on"

}

# Function to turn off a light
turn_off_light() {
    local sta_id=$1
    local entity_id="light.esp_train_tracker_${sta_id}"
    
    echo "⚫ Turning off ${entity_id}"
    
    DATA="{\"entity_id\": \"${entity_id}\"}"
    
    curl -X POST \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${DATA}" \
        "${HA_URL}/services/light/turn_off"
    
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

# Array to hold the IDs of the lights that ARE active (present in the JSON)
declare -a ACTIVE_LIGHT_IDS=()

echo "## Processing Active Trains from JSON"
# Use 'jq' to extract nextStaId and output_color for each train
# The -r flag is important to output raw strings
jq -r '.trains[] | "\(.nextStaId) \(.output_color)"' "$JSON_FILE" | while IFS=' ' read -r sta_id color; do
    
    # Check if sta_id is a valid number (0-255)
    if [[ "$sta_id" =~ ^[0-9]+$ ]] && (( sta_id >= 0 && sta_id <= 255 )); then
        # 1. Set the color for the active train light
        set_light_color "$sta_id" "$color"
        
        # 2. Record the ID as active
        ACTIVE_LIGHT_IDS+=("$sta_id")
    else
        echo "⚠️ Warning: Invalid nextStaId found: ${sta_id}. Skipping."
    fi
done

echo "--- Identifying and Turning Off Inactive Lights ---"

# Create a list of all possible light IDs (0 to 255)
# This is a good way to handle the requirement to turn off lights 0-255
for i in $(seq 0 255); do
    
    # Check if the current light ID is NOT in the ACTIVE_LIGHT_IDS array
    # The '[[ ! " ${array[*]} " =~ " $element " ]]' pattern is a robust Bash check
    if ! printf ' %s ' "${ACTIVE_LIGHT_IDS[@]}" | grep -q " ${i} "; then
        # The light is not active, so turn it off
        turn_off_light "$i"
    fi
done

echo "--- Script Finished Successfully ---"