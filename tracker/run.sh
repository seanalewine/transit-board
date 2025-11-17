#!/usr/bin/with-contenv bashio
website_name=$(bashio::config 'website_name')

touch /data/test_write.txt
if [ $? -eq 0 ]; then
    rm /data/test_write.txt
    echo "SUCCESS: Write access verified."
else
    echo "ERROR: Permission denied to write to /data."
fi

cp -v /files/. /data/

echo $(ls /data)

python3 -m http.server 8000 &

#Insert Function to pull and collate train data

wait