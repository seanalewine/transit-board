#!/usr/bin/with-contenv bashio

echo "Hello world!"

python3 -m http.server 8000

CONFIG_PATH=/data/options.json

PERLINE="$(bashio::config 'trainsPerLine')"

