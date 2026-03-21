ARG BUILD_FROM
FROM $BUILD_FROM

# Install only the necessary system libraries 
# (Most Python dependencies are handled by the pre-built wheels)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
# pip will automatically find the 'manylinux' wheels on Debian
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