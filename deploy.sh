#!/bin/bash

# ==============================================================================
# deploy.sh
# Automated deploy helper for Python Sandbox Service on Cloud Run.
# ==============================================================================

# Default configurations
DEFAULT_REGION="us-west1"

PROJECT_ID="${PROJECT_ID}"
REGION="${REGION:-$DEFAULT_REGION}"

# Prompt for Project ID if not set
if [ -z "$PROJECT_ID" ]; then
  # Try to read active gcloud project as default
  ACTIVE_PROJECT=$(gcloud config get-value project 2>/dev/null)
  if [ -n "$ACTIVE_PROJECT" ]; then
    printf "Please enter your GCP Project ID [%s]: " "$ACTIVE_PROJECT"
    read -r input_project
    PROJECT_ID="${input_project:-$ACTIVE_PROJECT}"
  else
    printf "Please enter your GCP Project ID: "
    read -r PROJECT_ID
  fi
fi

# Ensure PROJECT_ID is not empty
if [ -z "$PROJECT_ID" ]; then
  echo "Error: GCP Project ID is required." >&2
  exit 1
fi

echo "=============================================================================="
echo " Deploying Python Sandbox Service to Google Cloud Run"
echo "=============================================================================="
echo "Project ID:      $PROJECT_ID"
echo "Region:          $REGION"
echo "=============================================================================="

# Run gcloud deploy
gcloud run deploy sandbox \
  --source . \
  --region "$REGION" \
  --project "$PROJECT_ID" \
  --cpu 2 \
  --memory 4Gi \
  --sandbox-launcher \
  --no-invoker-iam-check

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo "=============================================================================="
  echo " Service deployed successfully!"
  echo "=============================================================================="
else
  echo "=============================================================================="
  echo " Deployment failed with exit code $EXIT_CODE." >&2
  echo "=============================================================================="
  exit $EXIT_CODE
fi
