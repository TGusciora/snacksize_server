# Stage 1: Build from Source
FROM ubuntu:22.04 AS builder

# Install build tools
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Clone the latest code
RUN git clone https://github.com/ggml-org/llama.cpp.git .

# Configure and Build
RUN cmake -B build -DLLAMA_BUILD_SERVER=ON
RUN cmake --build build --config Release --target llama-server -j1

# --- FIX: Collect ALL shared libraries ---
# This finds libllama.so, libggml.so, libmtmd.so, etc., wherever they are hiding
RUN mkdir -p /app/libs_to_copy && \
    find build -name "*.so*" -exec cp -P {} /app/libs_to_copy/ \;

# Stage 2: Runtime
FROM ubuntu:22.04

# Install runtime libraries
RUN apt-get update && apt-get install -y \
    libgomp1 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 1. Copy the executable
COPY --from=builder /app/build/bin/llama-server /usr/local/bin/llama-server

# 2. Copy ALL collected shared libraries to the system library path
COPY --from=builder /app/libs_to_copy/* /usr/lib/

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/llama-server"]
