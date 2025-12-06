#!/usr/bin/with-contenv bashio
# --- Configuration ---

# The total number of individually addressable LEDs on your strip.
# IMPORTANT: Adjust this value to match your actual hardware and HA configuration (e.g., 200 for 200 LEDs).
# Assuming 1-based indexing (LEDs 1 to TOTAL_LEDS). Adjust range in 'Inactive Lights' section if 0-based.
TOTAL_LEDS=64

# The full path to your JSON data file
JSON_FILE="/data/active_train_summary.json"

# The Home Assistant API endpoint for calling services
# Using 'supervisor/core/api' for communication within the add-on environment is often the most reliable method.
HA_API_URL="http://supervisor/core/api/services/light/addressable_set"

# The Home Assistant entity ID for your addressable light strip
LIGHT_ENTITY_ID=$(bashio::config 'light_board')

# Use a long-lived access token or the SUPERVISOR_TOKEN if available in your add-on.
# If SUPERVISOR_TOKEN is available, use: TOKEN="${SUPERVISOR_TOKEN}"
# Otherwise, replace YOUR_LONG_LIVED_ACCESS_TOKEN with your actual token.
# To get a long-lived token: Home Assistant -> Profile -> Create Token (at the bottom).
TOKEN="${SUPERVISOR_TOKEN}"

# Temporary file to store the indices of the LEDs that are explicitly turned ON by the JSON data.
ACTIVE_LEDS_FILE=$(mktemp)

# --- Script Logic ---

echo "Starting light update process for ${LIGHT_ENTITY_ID} (Total LEDs: ${TOTAL_LEDS})..."

# Cleanup function to ensure the temporary file is deleted on exit
cleanup() {
    rm -f "$ACTIVE_LEDS_FILE"
}
# Execute the cleanup function when the script exits (normally or via an error)
trap cleanup EXIT

# Check if the JSON file exists
if [[ ! -f "$JSON_FILE" ]]; then
    echo "Error: JSON file not found at $JSON_FILE" >&2
    exit 1
fi

# --- Phase 1: Turn ON/Color Active Lights and Collect Indices ---

echo "Phase 1: Coloring active train locations..."

# Use jq to iterate over the 'trains' array.
jq -c '.trains[]' "$JSON_FILE" | while read -r train_entry; do
    # 1. Extract the LED index and color
    LED_INDEX=$(echo "$train_entry" | jq -r '.nextStaId | tonumber | tostring')
    COLOR_STRING=$(echo "$train_entry" | jq -r '.output_color')

    # Input validation: check for valid index and within configured bounds
    if [[ -z "$LED_INDEX" || -z "$COLOR_STRING" || "$LED_INDEX" -lt 1 || "$LED_INDEX" -gt "$TOTAL_LEDS" ]]; then
        echo "Warning: Skipping invalid or out-of-range entry: $train_entry"
        continue
    fi

    # 2. Store the active index for later exclusion in Phase 2
    echo "$LED_INDEX" >> "$ACTIVE_LEDS_FILE"

    # 3. Construct the JSON payload to turn ON this specific segment
    PAYLOAD=$(cat <<EOF
{
  "entity_id": "$LIGHT_ENTITY_ID",
  "segments": [
    {
      "start": $LED_INDEX,
      "stop": $LED_INDEX,
      "color": {
        "rgb_color": [${COLOR_STRING}]
      }
    }
  ]
}
EOF
)
    # 4. Send API request in the background (concurrently)
    curl -X POST \
        -s -o /dev/null \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        "$HA_API_URL" &

done

# Wait for all background curl processes from Phase 1 to finish before proceeding
wait

# --- Phase 2: Turn OFF Inactive Lights ---

echo "Phase 2: Turning OFF all other LEDs (Setting color to [0, 0, 0])..."

# Generate the full list of indices (e.g., 1 to 200)
# Then use 'grep -v -f' to filter out all the indices found in the ACTIVE_LEDS_FILE.
seq 1 "$TOTAL_LEDS" | grep -v -f "$ACTIVE_LEDS_FILE" | while read -r INACTIVE_LED_INDEX; do

    # Construct the JSON payload to turn OFF this specific segment (by setting RGB to 0,0,0)
    OFF_PAYLOAD=$(cat <<EOF
{
  "entity_id": "$LIGHT_ENTITY_ID",
  "segments": [
    {
      "start": $INACTIVE_LED_INDEX,
      "stop": $INACTIVE_LED_INDEX,
      "color": {
        "rgb_color": [0, 0, 0]
      }
    }
  ]
}
EOF
)
    # Send API request for the inactive LED (concurrently)
    curl -X POST \
        -s -o /dev/null \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$OFF_PAYLOAD" \
        "$HA_API_URL" &

done

# Wait for all background curl processes from Phase 2 to finish
wait

echo "Light update process finished. Temporary file cleaned up."