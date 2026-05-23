# Python Sandboxed Code Executor

A lightweight, high-performance Go application designed to run Python code securely inside a sandboxed container environment on Google Cloud Run.

---

## Features

- Built using **Go 1.26** for minimal footprint and maximum execution speed.
- Native `net/http` server with zero third-party dependencies.
- Delegates code execution to Python 3 via the custom `/usr/local/gcp/bin/sandbox` CLI.

---

## Prerequisites

- **Go**: Version 1.26 or newer (if running or building locally)
- **Docker**: For container builds
- **Google Cloud SDK (gcloud CLI)**: Authenticated and configured with your project

---

## Project Structure

- `main.go`: The Go HTTP server implementing the routing, payload validation, escaping, and command execution logic.
- `Dockerfile`: A multi-stage Docker build that compiles the Go app in a secure builder environment and sets up the minimal Debian runtime environment with Python 3.

---

## Local Development & Testing

### 1. Running the Go server locally
To build and run the Go server locally without Docker:

```bash
# Build the binary
go build -o server main.go

# Start the server (runs on port 8080 by default)
PORT=8080 ./server
```

> [!NOTE]
> When running the server locally outside of Google Cloud Run, invocations to `/execute` will fail if `/usr/local/gcp/bin/sandbox` is not installed on your local system.

### 2. Building and running with Docker
To build the Docker image locally:

```bash
docker build -t sandbox-app .
```

To run the container:

```bash
docker run -p 8080:8080 sandbox-app
```

---

## Cloud Run Deployment

Deploy the service to Google Cloud Run using the `gcloud CLI`. This builds the container image securely using Cloud Build and provisions it to Cloud Run.

```bash
gcloud run deploy sandbox \
  --source . \
  --region europe-west9 \
  --project steren-run \
  --allow-unauthenticated
```

---

## API Testing Instructions

Once the server is running (either locally or on Cloud Run), you can test the endpoints using the commands below.

### 1. Check Service Status (GET `/`)

Request:
```bash
curl https://sandbox-879479752447.europe-west9.run.app/
```

Expected Response:
```text
Python code executor is running

Sample curl command to send Python code:
curl -X POST http://localhost:8080/execute \
  -H "Content-Type: application/json" \
  -d '{"code": "print(\"Hello from Sandbox!\")"}'
```

### 2. Execute Python Code (POST `/execute`)

Request:
```bash
curl -X POST https://sandbox-879479752447.europe-west9.run.app/execute \
  -H "Content-Type: application/json" \
  -d '{"code": "import sys; print(f\"Running Python {sys.version} inside Cloud Run!\")"}'
```

Expected Response:
```json
{
  "stdout": "Running Python 3.11.2 inside Cloud Run!\n",
  "stderr": ""
}
```
