# Python Sandboxed Code Executor

A lightweight, high-performance Go application designed to run Python code securely inside a sandboxed container environment on Google Cloud Run.

> [!IMPORTANT]
> The `/usr/local/gcp/bin/sandbox` execution binary is a secure environment wrapper provided specifically by Google Cloud Run. Because this binary is not present in local environments or standard Docker runtimes, the `/execute` endpoint will only function properly when deployed and running on Cloud Run.

---

## Deployment

Deploy the service to Google Cloud Run using the `gcloud` CLI:

```bash
gcloud run deploy sandbox \
  --source . \
  --region europe-west9 \
  --project steren-run \
  --execution-environment gen2 \
  --allow-unauthenticated
```

---

## Testing the Cloud Run Service

Once deployed, you can interact with the API endpoints using the examples below.

### 1. Check Service Status (GET `/`)

```bash
curl https://sandbox-879479752447.europe-west9.run.app/
```

### 2. Execute Python Code (POST `/execute`)

```bash
curl -X POST https://sandbox-879479752447.europe-west9.run.app/execute \
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
