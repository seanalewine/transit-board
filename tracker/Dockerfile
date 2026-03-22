ARG BUILD_FROM
FROM $BUILD_FROM AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-dev python3-venv build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create a virtual environment
RUN python3 -m venv /opt/venv
# Use the venv's pip to install
COPY requirements.txt /tmp/
RUN /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt

# --- Stage 2: Final Image ---
FROM $BUILD_FROM

RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata python3 && rm -rf /var/lib/apt/lists/*

# Copy the entire virtual environment
COPY --from=builder /opt/venv /opt/venv

# Ensure the app uses the venv by default
ENV PATH="/opt/venv/bin:$PATH"
# Set the working directory
WORKDIR /data

# Copy files
COPY files/. /files/
COPY run.sh /
RUN chmod a+x /run.sh

EXPOSE 8000

CMD [ "/run.sh" ]