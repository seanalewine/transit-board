ARG BUILD_FROM
FROM $BUILD_FROM

RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
# We use 'pip' directly as it's already configured in this base image
RUN pip install --no-cache-dir \
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