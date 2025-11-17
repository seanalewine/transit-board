#!/usr/bin/with-contenv bashio
website_name=$(bashio::config 'website_name')

echo "Hello world!"

python3 -m http.server 8000