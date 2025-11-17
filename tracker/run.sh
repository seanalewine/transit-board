#!/usr/bin/with-contenv bashio

echo "Hello world!"

cp -n files/index.html /data/index.html
cp -n files/trainLoc.json /data/trainLoc.json

python3 -m http.server 8000

CONFIG_PATH=/data/options.json

PERLINE="$(bashio::config 'trainsPerLine')"

