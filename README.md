# Python sandbox on Google Cloud Run

A lightweight, high-performance Go application designed to run Python code securely inside a sandboxed container environment on Google Cloud Run.

> [!IMPORTANT]
> The `/usr/local/gcp/bin/sandbox` execution binary is a secure environment wrapper provided specifically by Google Cloud Run. Because this binary is not present in local environments or standard Docker runtimes, the `/execute` endpoint will only function properly when deployed and running on Cloud Run.

---

## Deployment

The easiest way to deploy the service is using the automated deployment helper script:

```bash
# Deploys using defaults (prompts for GCP Project ID, defaults to us-west1 region)
bash deploy.sh
```

Alternatively, you can configure your environment variables and deploy manually using the `gcloud` CLI directly:

```bash
export PROJECT_ID="your-project-id"
export REGION="us-west1"

gcloud run deploy sandbox \
  --source . \
  --region $REGION \
  --project $PROJECT_ID \
  --cpu 4 \
  --memory 16Gi \
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

The project includes a concurrent load-testing wrapper script ([load_test.sh](load_test.sh)) built on top of [rakyll/hey](https://github.com/rakyll/hey).

It first runs baseline cold and warm start latency measurements, and then triggers a high-performance concurrent load test using `hey`.

### Prerequisites

Ensure you have `hey` installed:
```bash
# macOS
brew install hey
```

### Running the Load Test

You can execute the script directly using `bash`:

```bash
# Run with defaults (prompts for URL, uses 10 concurrency, 100 total sandboxes)
bash load_test.sh

# Run with customized limits directly: bash load_test.sh <url> <concurrency> <total_sandboxes>
bash load_test.sh $SERVICE_URL/execute 10 100
```

### Metrics Measured

`hey` natively captures and prints detailed execution statistics including:
- **Total Execution Duration & QPS Throughput**
- **Response Latency Distribution** (10%, 25%, 50%, 75%, 90%, 95%, 99% percentiles)
- **Status Code Distribution** (listing successful vs. failed runs)
- **Execution Histogram** (visual grouping of response distributions)

