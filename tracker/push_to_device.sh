#!/usr/bin/with-contenv bashio
# --- Configuration ---

# The total number of individually addressable LEDs on your strip.
# IMPORTANT: Adjust this value to match your actual hardware and HA configuration (e.g., 200 for 200 LEDs).
# Assuming 1-based indexing (LEDs 1 to TOTAL_LEDS). Adjust range in 'Inactive Lights' section if 0-based.
TOTAL_LEDS=64

# Use a long-lived access token or the SUPERVISOR_TOKEN if available in your add-on.
# If SUPERVISOR_TOKEN is available, use: TOKEN="${SUPERVISOR_TOKEN}"
# Otherwise, replace YOUR_LONG_LIVED_ACCESS_TOKEN with your actual token.
# To get a long-lived token: Home Assistant -> Profile -> Create Token (at the bottom).
TOKEN="${SUPERVISOR_TOKEN}"

# --- Configuration ---
# Internal Home Assistant API endpoint for Add-ons
HA_URL="http://supervisor/core/api"
# The token is automatically provided as an environment variable in HA Add-ons
HA_TOKEN="${SUPERVISOR_TOKEN}"
# Path to the input JSON file
INPUT_FILE="/data/active_train_summary.json"
# ESPHome Service and Target Entity
SERVICE_DOMAIN="esphome"
SERVICE_NAME="update_train_lights"
TARGET_ENTITY_ID=$(bashio::config 'light_board')

# --- Pre-flight Checks ---

# Check if the token is available
if [ -z "$HA_TOKEN" ]; then
    echo "Error: SUPERVISOR_TOKEN environment variable is not set." >&2
    exit 1
fi

# Check if the input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found at $INPUT_FILE" >&2
    exit 1
fi

# Check for required tools
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required but not installed. Please add it to your Add-on's Dockerfile." >&2
    exit 1
fi

# --- Main Logic ---

echo "Reading data from $INPUT_FILE..."

# 1. Read the entire JSON file as a raw string and embed it into the API payload.
# jq -Rs: Read the input file as a Raw String (R) and output as a single JSON string literal (s).
# The expression then builds the final service call payload.
API_PAYLOAD=$(jq -Rs \
  --arg entity_id "$TARGET_ENTITY_ID" \
  '{"entity_id": $entity_id, "train_data_json": .}' \
  "$INPUT_FILE")

# Check if payload generation was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to generate API payload using jq." >&2
    exit 1
fi

# 2. Call the Home Assistant Core API endpoint
API_ENDPOINT="${HA_URL}/services/${SERVICE_DOMAIN}/${SERVICE_NAME}"
echo "Calling HA API at $API_ENDPOINT..."

RESPONSE=$(
    curl -s -X POST \
    -H "Authorization: Bearer ${HA_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$API_PAYLOAD" \
    "$API_ENDPOINT"
)

# 3. Check curl exit status and API response for success
CURL_STATUS=$?

if [ $CURL_STATUS -ne 0 ]; then
    echo "Error: curl failed with exit status $CURL_STATUS" >&2
    exit 1
fi

# A successful API call returns an array of entity states (e.g., [{"entity_id": ...}]).
# An unsuccessful call (e.g., 400, 500) returns an error JSON object.
if echo "$RESPONSE" | jq -e '.[].entity_id' &> /dev/null; then
    echo "Success: ESPHome light service called successfully."
else
    # Output the full response for debugging if it's not the expected successful format
    echo "Error: API call failed. Response from Home Assistant:" >&2
    echo "$RESPONSE" | jq . >&2
    exit 1
fi

exit 0