#!/bin/bash
# Register the deployed agent with Gemini Enterprise

set -euo pipefail

if [ -z "${1:-}" ]; then
  echo "Usage: ./register.sh <reasoning-engine-path>"
  echo "Example: ./register.sh projects/<project-number>/locations/us-central1/reasoningEngines/123456"
  exit 1
fi

REASONING_ENGINE_PATH="$1"

# --- Configuration (update these) ---
GOOGLE_CLOUD_PROJECT="${GOOGLE_CLOUD_PROJECT:?Set GOOGLE_CLOUD_PROJECT}"
GE_APP_ID="${GE_APP_ID:?Set GE_APP_ID}"
GE_AUTH_RESOURCE="${GE_AUTH_RESOURCE:?Set GE_AUTH_RESOURCE}"

echo "=== Registering agent with Gemini Enterprise ==="
echo "Project: $GOOGLE_CLOUD_PROJECT"
echo "GE App: $GE_APP_ID"
echo "Auth Resource: $GE_AUTH_RESOURCE"
echo "Reasoning Engine: $REASONING_ENGINE_PATH"
echo ""

curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -H "X-Goog-User-Project: $GOOGLE_CLOUD_PROJECT" \
  "https://global-discoveryengine.googleapis.com/v1alpha/projects/$GOOGLE_CLOUD_PROJECT/locations/global/collections/default_collection/engines/$GE_APP_ID/assistants/default_assistant/agents" \
  -d @- <<EOF
{
  "displayName": "BigQuery Agent (ADK/Agent Engine)",
  "description": "BigQuery data analytics agent with end-user OAuth credentials",
  "adk_agent_definition": {
    "provisioned_reasoning_engine": {
      "reasoning_engine": "$REASONING_ENGINE_PATH"
    }
  },
  "authorization_config": {
    "tool_authorizations": [
      "$GE_AUTH_RESOURCE"
    ]
  }
}
EOF

echo ""
echo "=== Registration complete ==="
echo "Go to Gemini Enterprise console > Agents > Preview to test your agent."
