#!/usr/bin/with-contenv bashio
website_name=$(bashio::config 'website_name')
API_KEY=$(bashio::config 'api_key')
ROUTE_ID="red"

cp -rv /files/* /data/

echo $(ls /data)

python3 -m http.server 8000 &

./pulldata.sh API_KEY

wait