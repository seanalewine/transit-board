ARG BUILD_FROM
FROM $BUILD_FROM

# Install requirements for add-on
RUN \
  apk add --no-cache \
    python3

# Python 3 HTTP Server serves the current working dir
# So let's set it to our add-on persistent data directory.
WORKDIR /data

# Copy data for add-on
COPY files/. /files/
COPY run.sh /
COPY compile.sh /
COPY pulldata.sh /
COPY push_to_device.sh /
COPY testStateChange.sh /
RUN chmod a+x /testStateChange.sh
RUN chmod a+x /push_to_device.sh
RUN chmod a+x /run.sh
RUN chmod a+x /pulldata.sh
RUN chmod a+x /compile.sh

CMD [ "/run.sh" ]