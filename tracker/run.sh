#!/usr/bin/with-contenv bashio
set -o pipefail
#Define Variables
export API_KEY=$(bashio::config 'api_key')
CONFIG_PROG=$(bashio::config 'assign_stations_program')
export PERSIST_DIR="/data/position"
export CTA_STATION_LIST="/data/ctastationlist.csv"
LIGHT_BOARD_BASEPRE=$(bashio::config 'light_board')
export LIGHT_BOARD_BASE="${LIGHT_BOARD_BASEPRE}_"
export BIDIRECTIONAL=$(bashio::config 'bidirectional')
export TRAINS_PER_LINE=$(bashio::config 'trainsPerLine')
export BYPASS_MODE=$(bashio::config 'bypass_mode')
export DATA_REFRESH_INTERVAL_SEC=$(bashio::config 'data_refresh_interval_sec')
export JSON_FILE="/data/active_train_summary.json"
export RED_COLOR=$(bashio::config 'red_line_color')
export PINK_COLOR=$(bashio::config 'pink_line_color')
export ORANGE_COLOR=$(bashio::config 'orange_line_color')
export YELLOW_COLOR=$(bashio::config 'yellow_line_color')
export GREEN_COLOR=$(bashio::config 'green_line_color')
export BLUE_COLOR=$(bashio::config 'blue_line_color')
export PURPLE_COLOR=$(bashio::config 'purple_line_color')
export BROWN_COLOR=$(bashio::config 'brown_line_color')

#Install files to persistant storage.
cp -rv /files/* /data/

# Ensure share directory exists for persistent data
mkdir -p /share

# Create symlink for persistent station frequency file in web root
if [ -f /share/station_frequency.csv ]; then
    ln -sf /share/station_frequency.csv /data/station_frequency.csv
fi

# Start web server in background
python3 /data/webserver.py &

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
    python3 "/data/processor.py" | python3 "/data/graphicrefresh.py"

    if [ $? -eq 0 ]; then
        echo "--------------------------------------------------------"
        echo "Successfully completed processing and board refresh."
    else
        echo "--------------------------------------------------------"
        echo "Error: Python script failed."
    fi

    sleep "$DATA_REFRESH_INTERVAL_SEC"
done