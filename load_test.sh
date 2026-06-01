#!/bin/bash

# ==============================================================================
# load_test.sh
# Load-testing script for Python Sandbox Service using 'hey'.
# ==============================================================================

# Default configurations
DEFAULT_CONCURRENCY=10
DEFAULT_TOTAL_REQUESTS=100

# Check if 'hey' is installed
if ! command -v hey >/dev/null 2>&1; then
  echo "Error: 'hey' is not installed." >&2
  echo "Please install it using one of the following commands:" >&2
  echo "  macOS:  brew install hey" >&2
  echo "  Linux:  go install github.com/rakyll/hey@latest" >&2
  echo "  Web:    https://github.com/rakyll/hey" >&2
  exit 1
fi

TARGET_URL="$1"
CONCURRENCY="$2"
TOTAL_REQUESTS="$3"

# Prompt for URL if not provided as an argument
if [ -z "$TARGET_URL" ]; then
  printf "Please enter the target execution URL: "
  read -r TARGET_URL
fi

# Ensure TARGET_URL is not empty
if [ -z "$TARGET_URL" ]; then
  echo "Error: Target execution URL is required." >&2
  exit 1
fi

# Automatically append /execute to TARGET_URL if not already present
if [[ "$TARGET_URL" != */execute && "$TARGET_URL" != */execute/ ]]; then
  TARGET_URL="${TARGET_URL%/}/execute"
fi

# Prompt for Concurrency if not provided as an argument
if [ -z "$CONCURRENCY" ]; then
  printf "Please enter concurrency limit [%d]: " "$DEFAULT_CONCURRENCY"
  read -r CONCURRENCY
  CONCURRENCY="${CONCURRENCY:-$DEFAULT_CONCURRENCY}"
fi

# Prompt for Total Sandboxes if not provided as an argument
if [ -z "$TOTAL_REQUESTS" ]; then
  printf "Please enter total sandboxes to execute [%d]: " "$DEFAULT_TOTAL_REQUESTS"
  read -r TOTAL_REQUESTS
  TOTAL_REQUESTS="${TOTAL_REQUESTS:-$DEFAULT_TOTAL_REQUESTS}"
fi

# Helper function to get high-resolution epoch timestamp in seconds
get_time() {
  if command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes -e 'print Time::HiRes::time()'
  elif date +%s.%N | grep -qv "%N"; then
    date +%s.%N
  else
    date +%s
  fi
}

echo "=============================================================================="
echo " Starting Load Test on Python Sandbox Service using 'hey'"
echo "=============================================================================="
echo "Target URL:      $TARGET_URL"
echo "Concurrency:     $CONCURRENCY"
echo "Total Sandbox:   $TOTAL_REQUESTS"
echo "=============================================================================="

# 1. Baseline Cold and Warm Start Measurements
echo "Measuring baseline end to end latencies..."
cold_start=$(get_time)
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"code": "import time; print(\"Cold check\")"}' \
  "$TARGET_URL" > /dev/null
cold_end=$(get_time)
cold_latency=$(awk -v start="$cold_start" -v end="$cold_end" 'BEGIN {printf "%.4f", end - start}')
echo "cold start: ${cold_latency}s"

warm_start=$(get_time)
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"code": "import time; print(\"Warm check\")"}' \
  "$TARGET_URL" > /dev/null
warm_end=$(get_time)
warm_latency=$(awk -v start="$warm_start" -v end="$warm_end" 'BEGIN {printf "%.4f", end - start}')
echo "warm:       ${warm_latency}s"
echo "=============================================================================="

# 2. Executing concurrent sandboxes using hey
echo "Executing concurrent sandboxes..."

# Payload executes python code that outputs different values on every request
PAYLOAD='{"code": "import uuid, time; print(str(uuid.uuid4()) + \" \" + str(time.time()))"}'

hey -n "$TOTAL_REQUESTS" \
    -c "$CONCURRENCY" \
    -m POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$TARGET_URL"

echo "=============================================================================="
