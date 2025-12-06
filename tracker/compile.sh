#!/usr/bin/with-contenv bashio

# Define train line colors from config.yaml and EXPORT them as environment variables
export RED_COLOR=$(bashio::config 'red_line_color')
export PINK_COLOR=$(bashio::config 'pink_line_color')
export ORANGE_COLOR=$(bashio::config 'orange_line_color')
export YELLOW_COLOR=$(bashio::config 'yellow_line_color')
export GREEN_COLOR=$(bashio::config 'green_line_color')
export BLUE_COLOR=$(bashio::config 'blue_line_color')
export PURPLE_COLOR=$(bashio::config 'purple_line_color')
export BROWN_COLOR=$(bashio::config 'brown_line_color')

# --- DEFINITIONS ---
CTA_STATION_LIST="/data/ctastationlist.csv"
INPUT_DIR="/data/position"
OUTPUT_FILE="/data/active_train_summary.json"
# --- END DEFINITIONS ---

PYTHON_SCRIPT="/data/test.py"

echo "Starting data processing using Python..."
echo "--------------------------------------------------------"

# Execute the Python script, passing paths as arguments
python3 "$PYTHON_SCRIPT" \
    --station-list "$CTA_STATION_LIST" \
    --input-dir "$INPUT_DIR" \
    --output-file "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
    echo "--------------------------------------------------------"
    echo "Successfully completed processing. Output saved to $OUTPUT_FILE"
else
    echo "--------------------------------------------------------"
    echo "Error: Python script failed. Check logs for details."
fi

return