ARG BUILD_FROM
FROM $BUILD_FROM

RUN apk add --no-cache \
    build-base \
    tzdata \
    libstdc++ \
    openblas-dev

RUN python3 -m pip install --no-cache-dir --upgrade pip && \
    python3 -m pip install --no-cache-dir pandas requests numpy python-dateutil

# Set the working directory
WORKDIR /data

# Copy files
COPY files/. /files/
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]