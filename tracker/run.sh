#!/usr/bin/with-contenv bashio
website_name=$(bashio::config 'website_name')

echo "Hello world!"

echo "<h1>Not for humans</h1>" > /data/index.html

python3 -m http.server 8000