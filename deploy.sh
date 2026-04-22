#!/bin/bash
# Deploy BigQuery Agent to Vertex AI Agent Engine
# Then register it with Gemini Enterprise

set -euo pipefail

# --- Configuration (update these) ---
export GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT:?Set GOOGLE_CLOUD_PROJECT}"
export GOOGLE_CLOUD_LOCATION="${GOOGLE_CLOUD_LOCATION:-us-central1}"

echo "=== Step 1: Deploy to Vertex AI Agent Engine ==="
echo "Project: $GOOGLE_CLOUD_PROJECT"
echo "Location: $GOOGLE_CLOUD_LOCATION"
echo ""

adk deploy agent_engine \
  --display_name="BQ Agent for Gemini Enterprise" \
  bigquery_agent

echo ""
echo "=== Deployment complete ==="
echo ""
echo "Copy the reasoning engine path from above (projects/.../reasoningEngines/...)"
echo "Then run:"
echo "  ./register.sh <reasoning-engine-path>"
