# Python sandbox on Google Cloud Run

A lightweight, high-performance Go application designed to run Python code securely inside a sandboxed container environment on Google Cloud Run.

> [!IMPORTANT]
> The `/usr/local/gcp/bin/sandbox` execution binary is a secure environment wrapper provided specifically by Google Cloud Run. Because this binary is not present in local environments or standard Docker runtimes, the `/execute` endpoint will only function properly when deployed and running on Cloud Run.

---

## Deployment

Set your Google Cloud Project ID and region as environment variables, and deploy the service using the `gcloud` CLI:

```bash
export PROJECT_ID="your-project-id"
export REGION="europe-west9"

gcloud run deploy sandbox \
  --source . \
  --region $REGION \
  --project $PROJECT_ID \
  --execution-environment gen2 \
  --allow-unauthenticated
```

---

## Testing the Cloud Run Service

Once deployed, retrieve the service URL using the `gcloud` CLI and query the API endpoints:

```bash
# Get the live Cloud Run Service URL
export SERVICE_URL=$(gcloud run services describe sandbox --region $REGION --format 'value(status.url)')
```

### 1. Check Service Status (GET `/`)

```bash
curl $SERVICE_URL/
```

### 2. Execute Python Code (POST `/execute`)

```bash
curl -X POST $SERVICE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{"code": "import sys; print(f\"Running Python {sys.version} inside Cloud Run!\")"}'
```

**Expected Response:**
```json
{
  "stdout": "Running Python 3.11.2 inside Cloud Run!\n",
  "stderr": ""
}
```

---

## Load Testing

The project includes a concurrent, zero-dependency load-testing script ([load_test.sh](load_test.sh)) to stress-test your deployed Cloud Run service.

It monitors active background process pools, enforces a strict concurrency ceiling, dynamically generates unique Python payloads per request to bypass runtime caching, and computes detailed execution and latency metrics.

### Running the Load Test

You can execute the script directly using `bash`:

```bash
# Run with defaults (prompts for URL, uses 10 concurrency, 100 total requests)
bash load_test.sh

# Run with customized limits directly: bash load_test.sh <url> <concurrency> <total_requests>
bash load_test.sh $SERVICE_URL/execute 10 100
```

### Metrics Measured

- **Total Execution Time**: Total time taken to complete the entire test run.
- **Max Peak Concurrency Sandbox**: Peak concurrent sandbox executions achieved during the run.
- **Total Sandboxes Created**: Total successful execution counts (HTTP 200).
- **Total Sandbox**: Total number of sandboxes requested.
- **Latency Percentiles**: End-to-End processing latencies (Average, p50, p90, p95, p99).

