ARG BUILD_FROM
FROM $BUILD_FROM AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    python3-dev \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy only requirements first to protect the cache
COPY requirements.txt /tmp/
RUN python3 -m pip wheel --no-cache-dir --wheel-dir /install \
    --break-system-packages \
    -r /tmp/requirements.txt

# --- Stage 2: The Final Image ---
FROM $BUILD_FROM

RUN apt-get update && apt-get install -y --no-install-recommends \
    tzdata \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Copy wheels from builder
COPY --from=builder /install /install
RUN python3 -m pip install --no-index --find-links=/install /install/* \
    --break-system-packages \
    && rm -rf /install
# Set the working directory
WORKDIR /data

# Copy files
COPY files/. /files/
COPY run.sh /
RUN chmod a+x /run.sh

CMD [ "/run.sh" ]