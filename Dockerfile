# Stage 1: Build the Go binary
FROM golang:1.26-bookworm AS builder

WORKDIR /src

# Copy source file
COPY main.go ./

# Initialize go module and build directly
RUN go mod init sandbox-app && \
    go build -o /app/server main.go

# Stage 2: Final runtime environment
FROM debian:bookworm-slim

# Install Python3
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 && \
    rm -rf /var/lib/apt/lists/*

# Create a stub/wrapper for the "sandbox" CLI so the application runs successfully inside the container.
# If a real sandbox binary exists at /usr/bin/sandbox, it will delegate to it; otherwise, it executes python directly.
RUN echo '#!/bin/sh\n\
if [ -x /usr/bin/sandbox ]; then\n\
  exec /usr/bin/sandbox "$@"\n\
fi\n\
if [ "$1" = "do" ] && [ "$2" = "--" ]; then\n\
  shift 2\n\
fi\n\
exec "$@"' > /usr/local/bin/sandbox && \
chmod +x /usr/local/bin/sandbox

# Copy the compiled Go server from the builder stage
COPY --from=builder /app/server /usr/local/bin/server

# Expose port
EXPOSE 8080

# Run the compiled binary
CMD [ "server" ]
