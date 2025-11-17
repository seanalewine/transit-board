#!/usr/bin/with-contenv bashio
website_name=$(bashio::config 'website_name')

cp -n /files/. /data/

echo $(ls /files)

python3 -m http.server 8000

echo "Hello after python"