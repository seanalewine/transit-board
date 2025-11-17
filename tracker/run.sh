#!/usr/bin/with-contenv bashio
website_name=$(bashio::config 'website_name')

echo "Hello world!"

cp -r files /share/htdocs

python3 -m http.server 8000