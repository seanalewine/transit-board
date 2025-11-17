#!/usr/bin/with-contenv bashio
website_name=$(bashio::config 'website_name')
API_KEY=$(bashio::config 'api_key')
ROUTE_ID="red"

cp -rv /files/* /data/

#echo $(ls /data)

# --- Start the HTTP Server ---
# Start the Python server in the background (&)
echo "Starting Python HTTP Server on port 8000..."
python3 -m http.server 8000 &

# --- Recurring Data Fetch Loop ---
echo "Starting recurring data fetch loop..."
while true; do
    # Run the data refresh script
    echo "--- Running data refresh: /pulldata.sh"
    # The 'source' command is used to run the script in the current environment
    source /pulldata.sh "$API_KEY"
    echo "--- Data refresh complete."

    # Wait for 60 seconds before running again
    sleep 60
done