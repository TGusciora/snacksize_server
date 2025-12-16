# # Stage 1: Build from Source
# We kick things off with a standard Ubuntu environment. 
# We call this stage "builder" because it's just here to compile the code, not to run it permanently.
FROM ubuntu:22.04 AS builder

# Install build tools
# Here we are prepping our toolbox. We need 'build-essential' (compilers), 
# 'cmake' (to manage the build process), and 'git' (to download the code).
#  It's like buying all your ingredients before you start cooking.
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    curl \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory to /app. 
# From now on, any command we run happens inside this folder.
WORKDIR /app

# Clone the latest code
# We are downloading the raw source code directly from the repository.
# Note: We are building from scratch to get the absolute latest features.
RUN git clone https://github.com/ggml-org/llama.cpp.git .

# # Configure and Build
# First, we configure the project with CMake. 
# The flag -DLLAMA_BUILD_SERVER=ON is crucial—it tells the builder, 
# "Hey, we specifically want the HTTP server, not just the command line tool."
RUN cmake -B build -DLLAMA_BUILD_SERVER=ON

# Now we actually compile the code (Release mode for speed).
# The flag '-j1' is the "safety first" approach. It limits the builder to 1 CPU core.
# Why? Because compiling C++ sucks up RAM like a vacuum cleaner. 
# Using -j1 prevents your machine from crashing, even if it takes a bit longer.
RUN cmake --build build --config Release --target llama-server -j1

# --- FIX: Collect ALL shared libraries ---
# This acts as a scavenger hunt. 
# Sometimes the build produces shared libraries (.so files) scattered in different folders.
# This command finds them all and copies them to one spot so we don't lose them later.
RUN mkdir -p /app/libs_to_copy && \
    find build -name "*.so*" -exec cp -P {} /app/libs_to_copy/ \;

# # Stage 2: Runtime
# NOW we start the fresh, final image. 
# We discard all the heavy compilers from the "builder" stage and start with a clean Ubuntu.
FROM ubuntu:22.04

# Install runtime libraries
# We only install what is strictly needed to run the program (runtime dependencies),
# keeping the final image size much smaller than the builder stage.
RUN apt-get update && apt-get install -y \
    libgomp1 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 1. Copy the executable
# We reach back into the "builder" stage and grab ONLY the 'llama-server' executable.
COPY --from=builder /app/build/bin/llama-server /usr/local/bin/llama-server

# 2. Copy ALL collected shared libraries to the system library path
# We also grab those shared libraries we rescued earlier and put them 
# directly in the system's library folder so the server finds them immediately. 
COPY --from=builder /app/libs_to_copy/* /usr/lib/

# Set entrypoint
# This tells Docker: "When this container starts, run this command immediately."
ENTRYPOINT ["/usr/local/bin/llama-server"]