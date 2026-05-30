#!/bin/bash

# ==============================================================================
# load_test.sh
# Zero-dependency, concurrent load-testing script for Python Sandbox Service.
# ==============================================================================

# Default configurations
DEFAULT_URL="https://sandbox-879479752447.europe-west9.run.app/execute"
DEFAULT_CONCURRENCY=5
DEFAULT_TOTAL_REQUESTS=50

TARGET_URL="${1:-$DEFAULT_URL}"
CONCURRENCY="${2:-$DEFAULT_CONCURRENCY}"
TOTAL_REQUESTS="${3:-$DEFAULT_TOTAL_REQUESTS}"

# Working directory & Temp log files
WORK_DIR="$(pwd)/.load_test_tmp"
mkdir -p "$WORK_DIR"
RESULTS_FILE="$WORK_DIR/results.log"
SORTED_FILE="$WORK_DIR/results_sorted.log"

# Clean up any old results
> "$RESULTS_FILE"

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

# Function to run a single request
run_request() {
  local req_id="$1"
  local start_time=$(get_time)

  # Unique python code that outputs different values on every single request
  local python_code="import uuid, time; print('Request ID: ${req_id} | UUID: ' + str(uuid.uuid4()) + ' | Epoch: ' + str(time.time()))"
  local payload="{\"code\": \"$python_code\"}"

  # Execute Curl and capture HTTP Status Code and Response Body
  local response
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$TARGET_URL" 2>/dev/null)

  local exit_code=$?
  local end_time=$(get_time)

  # Extract latency and HTTP status code
  local latency=$(awk -v start="$start_time" -v end="$end_time" 'BEGIN {print end - start}')
  local http_status=$(echo "$response" | tail -n 1)

  if [ $exit_code -ne 0 ] || [ -z "$http_status" ]; then
    http_status="ERROR"
  fi

  # Record results format: <latency_seconds> <http_status>
  echo "$latency $http_status" >> "$RESULTS_FILE"
}

echo "=============================================================================="
echo " Starting Load Test on Python Sandbox Service"
echo "=============================================================================="
echo "Target URL:      $TARGET_URL"
echo "Concurrency:     $CONCURRENCY"
echo "Total Requests:  $TOTAL_REQUESTS"
echo "=============================================================================="
echo "Sending concurrent requests..."

total_start_time=$(get_time)
peak_concurrency=0

# Run requests concurrently
for i in $(seq 1 "$TOTAL_REQUESTS"); do
  # Run request in background
  run_request "$i" &

  # Dynamic concurrency monitoring and peak detection
  while true; do
    active_jobs=$(jobs -r | wc -l | tr -d ' ')
    if [ "$active_jobs" -gt "$peak_concurrency" ]; then
      peak_concurrency=$active_jobs
    fi

    # Throttling to enforce concurrency limit
    if [ "$active_jobs" -lt "$CONCURRENCY" ]; then
      break
    fi
    sleep 0.02
  done
done

# Wait for remaining background requests to finish
echo "Waiting for remaining executions to finish..."
while true; do
  active_jobs=$(jobs -r | wc -l | tr -d ' ')
  if [ "$active_jobs" -gt "$peak_concurrency" ]; then
    peak_concurrency=$active_jobs
  fi
  if [ "$active_jobs" -eq 0 ]; then
    break
  fi
  sleep 0.02
done

total_end_time=$(get_time)

# ==============================================================================
# Post-Processing & Metrics Generation
# ==============================================================================

if [ ! -s "$RESULTS_FILE" ]; then
  echo "Error: No results captured during load test."
  rm -rf "$WORK_DIR"
  exit 1
fi

# Sort results file by latency (column 1) for percentile processing
sort -n -k 1 "$RESULTS_FILE" > "$SORTED_FILE"

# Process sorted logs with awk to calculate statistics
metrics=$(awk '
  BEGIN {
    count = 0
    success_count = 0
    total_latency = 0
  }
  {
    latencies[count] = $1
    status = $2
    total_latency += $1
    if (status == "200") {
      success_count++
    }
    count++
  }
  END {
    if (count == 0) {
      print "0 0 0 0 0 0 0"
      exit
    }
    avg = total_latency / count

    # Percentiles calculation (0-indexed)
    p50_idx = int(count * 0.50)
    p90_idx = int(count * 0.90)
    p95_idx = int(count * 0.95)
    p99_idx = int(count * 0.99)

    # Upper boundary checks
    if (p50_idx >= count) p50_idx = count - 1
    if (p90_idx >= count) p90_idx = count - 1
    if (p95_idx >= count) p95_idx = count - 1
    if (p99_idx >= count) p99_idx = count - 1

    printf "%d %d %f %f %f %f %f\n", success_count, count, avg, latencies[p50_idx], latencies[p90_idx], latencies[p95_idx], latencies[p99_idx]
  }
' "$SORTED_FILE")

# Extract metrics fields
total_success=$(echo "$metrics" | cut -d' ' -f1)
total_requests=$(echo "$metrics" | cut -d' ' -f2)
avg_latency=$(echo "$metrics" | cut -d' ' -f3)
p50=$(echo "$metrics" | cut -d' ' -f4)
p90=$(echo "$metrics" | cut -d' ' -f5)
p95=$(echo "$metrics" | cut -d' ' -f6)
p99=$(echo "$metrics" | cut -d' ' -f7)

# Calculate total execution duration
total_duration=$(awk -v start="$total_start_time" -v end="$total_end_time" 'BEGIN {print end - start}')

# Calculate executed sandboxes per minute (RPM)
rpm=$(awk -v success="$total_success" -v duration="$total_duration" 'BEGIN {
  if (duration > 0) {
    print (success / duration) * 60
  } else {
    print 0
  }
}')

# Display metrics report
echo "=============================================================================="
echo " Load Test Metrics Summary"
echo "=============================================================================="
printf "Total Execution Time:             %.3f seconds\n" "$total_duration"
printf "Max Peak Concurrency Sandbox:     %d sandboxes\n" "$peak_concurrency"
printf "Total Sandboxes Created (Success): %d (HTTP 200)\n" "$total_success"
printf "Total Requests Sent:              %d\n" "$total_requests"
printf "Executed Sandboxes Per Minute:    %.2f RPM\n" "$rpm"
echo "------------------------------------------------------------------------------"
echo " End-to-End Latency Percentiles (Seconds):"
echo "------------------------------------------------------------------------------"
printf "  Average (Mean):                 %.4fs\n" "$avg_latency"
printf "  50th Percentile (Median):       %.4fs\n" "$p50"
printf "  90th Percentile (p90):          %.4fs\n" "$p90"
printf "  95th Percentile (p95):          %.4fs\n" "$p95"
printf "  99th Percentile (p99):          %.4fs\n" "$p99"
echo "=============================================================================="

# Cleanup working directory
rm -rf "$WORK_DIR"
