#!/usr/bin/with-contenv bashio
#Define API Key from config.yaml
TARGET_STATE=$(bashio::config 'state')
ENTITY_ID=$(bashio::config 'light_board')
# Home Assistant Light State Controller
#
# This script executes a light service call (turn_on or turn_off)
# against the Home Assistant Core API using environment variables
# provided by the add-on execution environment.
#
# Global Variables Required:
# 1. TARGET_STATE: 'true' (ON) or 'false' (OFF)
# 2. ENTITY_ID: The Home Assistant entity ID (e.g., light.porch)
# 3. SUPERVISOR_TOKEN: The long-lived access token for API authentication (usually auto-provided)

set -euo pipefail

# --- Configuration ---
# HA_URL points to the internal supervisor endpoint, which acts as a proxy to the HA Core API.
readonly HA_URL="http://supervisor/core/api"
readonly API_ENDPOINT="${HA_URL}/services"

# --- Environment Variable Validation ---

if [[ -z "${SUPERVISOR_TOKEN:-}" ]]; then
    echo "Error: SUPERVISOR_TOKEN environment variable is not set. Cannot authenticate with Home Assistant."
    exit 1
fi

if [[ -z "${ENTITY_ID:-}" ]]; then
    echo "Error: ENTITY_ID environment variable is not set. Aborting."
    exit 1
fi

if [[ -z "${TARGET_STATE:-}" ]]; then
    echo "Error: TARGET_STATE environment variable is not set ('true' or 'false' expected). Aborting."
    exit 1
fi

# Sanitize and normalize the input state
NORMALIZED_STATE=$(echo "${TARGET_STATE}" | tr '[:upper:]' '[:lower:]')

# --- Determine Service Call ---

SERVICE_DOMAIN="light"
SERVICE=""

if [[ "${NORMALIZED_STATE}" == "true" ]]; then
    SERVICE="turn_on"
elif [[ "${NORMALIZED_STATE}" == "false" ]]; then
    SERVICE="turn_off"
else
    echo "Error: TARGET_STATE must be 'true' or 'false'. Received '${TARGET_STATE}'. Aborting."
    exit 1
fi

# --- Construct Request ---

FULL_SERVICE_URL="${API_ENDPOINT}/${SERVICE_DOMAIN}/${SERVICE}"
JSON_PAYLOAD="{\"entity_id\": \"${ENTITY_ID}\"}"

echo "Attempting to call service: ${SERVICE_DOMAIN}.${SERVICE}"
echo "Target Entity ID: ${ENTITY_ID}"
echo "API Endpoint: ${FULL_SERVICE_URL}"
echo "Payload: ${JSON_PAYLOAD}"

# --- Execute API Call using curl ---

# The -s (silent) and -S (show errors) flags are used for cleaner output,
# and -X POST specifies the HTTP method.
# -H sets the required headers: Authorization and Content-Type.
# -d sends the JSON payload.
CURL_RESPONSE=$(curl -s -S -X POST \
  -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${JSON_PAYLOAD}" \
  "${FULL_SERVICE_URL}" 2>&1) # Redirect stderr to stdout for pipefail safety

CURL_EXIT_CODE=$?

# --- Result Handling ---

if [[ ${CURL_EXIT_CODE} -eq 0 ]]; then
    echo "Success: Light state updated."
    # Optionally display the response from HA (usually empty array on success)
    # echo "Response: ${CURL_RESPONSE}"
else
    echo "Failure: curl command exited with status ${CURL_EXIT_CODE}."
    echo "Error Response: ${CURL_RESPONSE}"
    exit 1
fi