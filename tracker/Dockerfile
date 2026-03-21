ARG BUILD_FROM
FROM $BUILD_FROM

RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    python3 \
    python3-pip \
    python3-setuptools \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages using the python module flag
RUN python3 -m pip install --no-cache-dir --break-system-packages \
    requests \
    numpy \
    python-dateutil \
    pandas
# Set the working directory
WORKDIR /data

# Copy files
COPY files/. /files/
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]