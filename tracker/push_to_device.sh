#!/usr/bin/with-contenv bashio

# --- Configuration: Replace the HA_TOKEN and HA_URL Placeholders ---
# Read the base entity name from the Add-on's configuration (config.json)
# If your config.json has "light_board": "light.my_train_lights", 
# then LIGHT_BOARD_BASE will be "light.my_train_lights".
LIGHT_BOARD_BASE=$(bashio::config 'light_board')


# Your Home Assistant URL/IP and port
HA_URL="http://homeassistant.local:8123"

# Path to the input JSON file (as specified in the prompt)
JSON_FILE="/data/active_train_summary.json"

# Total number of LEDs to check for turning off (from 0 to MAX_LED_INDEX)
MAX_LED_INDEX=255
# -------------------------------------------------------------------

# Set up the cURL headers
CURL_HEADERS=(-H "Authorization: Bearer ${SUPERVISOR_TOKEN}" -H "Content-Type: application/json")

# 1. Parse JSON and Turn ON Lights
echo "🚂 Processing active trains and setting LED colors..."
echo "----------------------------------------------------"
echo "Using Light Board Base Entity: ${LIGHT_BOARD_BASE}"

# Initialize an associative array to track which LEDs are active
declare -A active_leds

# Use 'jq' to process the JSON file. It extracts the necessary fields
train_data=$(jq -r '.trains[] | "\(.nextStaId) \(.red) \(.green) \(.blue)"' "${JSON_FILE}" | sed 's/%//g')

# Read the data line by line
while read -r sta_id red_percent green_percent blue_percent; do
    if [[ -z "$sta_id" ]]; then
        continue
    fi
    
    # Convert percentage to 0-255 range: round((percent / 100) * 255)
    red_value=$(echo "scale=0; (${red_percent} / 100) * 255" | bc -l)
    green_value=$(echo "scale=0; (${green_percent} / 100) * 255" | bc -l)
    blue_value=$(echo "scale=0; (${blue_percent} / 100) * 255" | bc -l)

    # Ensure integer values and limit to 255
    red_value=$(($red_value > 255 ? 255 : $red_value))
    green_value=$(($green_value > 255 ? 255 : $green_value))
    blue_value=$(($blue_value > 255 ? 255 : $blue_value))

    # --- UPDATED ENTITY_ID ---
    # Construct the final ENTITY_ID using the configured base and the station ID
    ENTITY_ID="${LIGHT_BOARD_BASE}_${sta_id}"
    
    SERVICE_DATA=$(jq -n \
        --arg entity "${ENTITY_ID}" \
        --argjson r "$red_value" \
        --argjson g "$green_value" \
        --argjson b "$blue_value" \
        '{ "entity_id": $entity, "rgb_color": [$r, $g, $b] }')

    echo "  -> Setting ${ENTITY_ID} to RGB(${red_value}, ${green_value}, ${blue_value})"

    # Call the Home Assistant API to turn the light ON
    curl -s -X POST "http://supervisor/core/api/services/light/turn_on" \
        "${CURL_HEADERS[@]}" \
        -d "${SERVICE_DATA}" > /dev/null

    # Mark this LED as active
    active_leds["$sta_id"]=1

done <<< "$train_data"

echo "----------------------------------------------------"
echo "✅ Finished setting active train lights."

# ---

# 2. Turn OFF Unused Lights (0-255)
echo "Turning OFF lights that are not listed in the summary (0-${MAX_LED_INDEX})..."
echo "----------------------------------------------------"

# Loop through all possible LED indices (0 to MAX_LED_INDEX)
for (( i=0; i<=$MAX_LED_INDEX; i++ )); do
    # Check if this index was NOT in the active_leds array
    if [[ -z "${active_leds[$i]:-}" ]]; then
        # --- UPDATED ENTITY_ID ---
        ENTITY_ID="${LIGHT_BOARD_BASE}_${i}"
        
        SERVICE_DATA=$(jq -n --arg entity "${ENTITY_ID}" '{ "entity_id": $entity }')

        echo "  -> Turning off ${ENTITY_ID}"

        # Call the Home Assistant API to turn the light OFF
        curl -s -X POST "${HA_URL}/api/services/light/turn_off" \
            "${CURL_HEADERS[@]}" \
            -d "${SERVICE_DATA}" > /dev/null
    fi
done

echo "----------------------------------------------------"
echo "Train light update complete!"