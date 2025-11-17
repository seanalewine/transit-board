#!/usr/bin/with-contenv bashio
website_name=$(bashio::config 'website_name')

cp -rnv /files/. /data/

echo $(ls /data)

python3 -m http.server 8000 &

#Insert Function to pull and collate train data

wait