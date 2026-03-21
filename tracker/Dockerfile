ARG BUILD_FROM
FROM $BUILD_FROM

# Install requirements for add-on
RUN apk add --no-cache \
    python3 \
    py3-pip \
    gcc \
    g++ \
    musl-dev \
    linux-headers \
    libffi-dev \
    openssl-dev

# Install python packages
RUN pip install --no-cache-dir requests numpy python-dateutil pandas

# Clean up build dependencies (optional but recommended)
RUN apk del gcc g++ musl-dev linux-headers libffi-dev openssl-dev


# Python 3 HTTP Server serves the current working dir
# So let's set it to our add-on persistent data directory.
WORKDIR /data

# Copy data for add-on
COPY files/. /files/
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]