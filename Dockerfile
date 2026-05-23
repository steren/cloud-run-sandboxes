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

# Copy the compiled Go server from the builder stage
COPY --from=builder /app/server /usr/local/bin/server

# Expose port
EXPOSE 8080

# Run the compiled binary
CMD [ "server" ]
