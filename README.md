# Python sandbox on Google Cloud Run

A lightweight, high-performance Go application designed to run Python code securely inside a sandboxed container environment on Google Cloud Run.

> [!IMPORTANT]
> The `/usr/local/gcp/bin/sandbox` execution binary is a secure environment wrapper provided specifically by Google Cloud Run. Because this binary is not present in local environments or standard Docker runtimes, the `/execute` endpoint will only function properly when deployed and running on Cloud Run.

---

## Deployment

Set your Google Cloud Project ID as an environment variable and deploy the service using the `gcloud` CLI:

```bash
export PROJECT_ID="your-project-id"

gcloud run deploy sandbox \
  --source . \
  --region europe-west9 \
  --project $PROJECT_ID \
  --execution-environment gen2 \
  --allow-unauthenticated
```

---

## Testing the Cloud Run Service

Once deployed, retrieve the service URL using the `gcloud` CLI and query the API endpoints:

```bash
# Get the live Cloud Run Service URL
export SERVICE_URL=$(gcloud run services describe sandbox --region europe-west9 --format 'value(status.url)')
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
