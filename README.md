# Python sandbox on Google Cloud Run

A lightweight, high-performance Go application designed to run Python code securely inside a sandboxed container environment on Google Cloud Run.

> [!IMPORTANT]
> The `/usr/local/gcp/bin/sandbox` execution binary is a secure environment wrapper provided specifically by Google Cloud Run. Because this binary is not present in local environments or standard Docker runtimes, the `/execute` endpoint will only function properly when deployed and running on Cloud Run.

---

## Deployment

```bash
# Deploys using defaults (prompts for GCP Project ID, defaults to us-west1 region)
bash deploy.sh
```

Alternatively, you can configure your environment variables and deploy manually using the `gcloud` CLI directly:

```bash
gcloud beta run deploy sandbox \
  --source . \
  --cpu 2 \
  --memory 4Gi \
  --max 100 \
  --sandbox-launcher \
  --no-invoker-iam-check
```

> [!TIP]
> For better performance during the load test, we recommend using min instances. For example, you can append `--min 10` to your deployment command.

---

## Testing the Cloud Run Service

Once deployed, retrieve the service URL using the `gcloud` CLI and query the API endpoints:

```bash
# Get the live Cloud Run Service URL
export SERVICE_URL=$(gcloud beta run services describe sandbox --format 'value(status.url)')
```

### Execute Python Code (POST `/execute`)

```bash
curl -X POST $SERVICE_URL/execute \
  -H "Content-Type: application/json" \
  -d '{"code": "import sys; print(f\"Running untrusted Python {sys.version}  inside a Cloud Run sandbox\")"}'
```

**Expected Response:**
```json
{
  "stdout": "Running untrusted Python 3.11.2  inside a Cloud Run sandbox\n",
  "stderr": ""
}
```

---

## Load Testing

We use [hatoo/oha](https://github.com/hatoo/oha) to perform high-performance concurrent load testing on the Python sandbox service.

### Prerequisites

Ensure you have `oha` installed:
```bash
# macOS
brew install oha
```

### Running the Load Test

Run the raw `oha` command directly with the inlined Python payload:

```bash
oha -n 1000 -c 100 -m POST \
  -H "Content-Type: application/json" \
  -d '{"code": "import uuid, time; print(str(uuid.uuid4()) + \" \" + str(time.time()))"}' \
  $SERVICE_URL/execute
```

### Metrics Measured

`oha` natively captures and prints detailed execution statistics including:
- **Total Execution Duration & QPS Throughput**
- **Response Latency Distribution** (10%, 25%, 50%, 75%, 90%, 95%, 99% percentiles)
- **Status Code Distribution** (listing successful vs. failed runs)
- **Execution Histogram** (visual grouping of response distributions)

