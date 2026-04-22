# BigQuery Agent on Gemini Enterprise with End-User OAuth — Step-by-Step Guide

## What We Built

An ADK (Agent Development Kit) agent that lets users query BigQuery data through Gemini Enterprise, using **their own OAuth credentials** (not a shared service account). This means each user only sees data they're authorized to access.

## Architecture

```
User → Gemini Enterprise → OAuth consent → Agent Engine → ADK Agent → BigQuery
                                ↑                              ↑
                        Auth Resource                   Uses user's
                      (manages OAuth flow)             access token
```

## Prerequisites

- Google Cloud project with these APIs enabled:
  - Vertex AI API
  - BigQuery API
  - Discovery Engine API
- Gemini Enterprise app already initialized
- `gcloud` CLI authenticated
- `uv` (or `pip`) and Python 3.12+
- `google-adk >= 1.25.0`

## Step 1: Create the Project Structure

```
bq-agent-ge/
├── bigquery_agent/
│   ├── __init__.py
│   ├── agent.py
│   └── .env
├── pyproject.toml
├── deploy.sh
└── register.sh
```

```bash
uv venv bq-agent-ge/venv
```

## Step 2: Create the Agent Code

See `bigquery_agent/agent.py` for the full implementation. Key points:

- Uses `AuthCredentialTypes.HTTP` to accept access tokens from Gemini Enterprise
- `AUTH_ID` is loaded from the `GE_AUTH_ID` environment variable and must match your Gemini Enterprise authorization resource ID
- `BigQueryToolset` handles all BQ operations (list datasets, tables, execute SQL, etc.)
- Write mode is set to `BLOCKED` (read-only) — change to `ALLOWED` or `PROTECTED` if needed

## Step 3: Configure Environment

Update `bigquery_agent/.env` with your project details:

```
GOOGLE_GENAI_USE_VERTEXAI=TRUE
GOOGLE_CLOUD_PROJECT=your-project-id
GOOGLE_CLOUD_LOCATION=us-central1
GE_AUTH_ID=your-auth-id
```

## Step 4: Create an OAuth 2.0 Client

1. Go to **Cloud Console > APIs & Credentials > + CREATE CREDENTIALS > OAuth client ID**
2. Application type: **Web application**
3. Add **two** Authorized redirect URIs:
   - `https://vertexaisearch.cloud.google.com/static/oauth/oauth.html`
   - `https://vertexaisearch.cloud.google.com/oauth-redirect`
4. Save the **Client ID** and **Client Secret**

## Step 5: Create the Authorization Resource in Gemini Enterprise

This is the bridge that manages the OAuth flow and passes access tokens to your agent.

```bash
export GOOGLE_CLOUD_PROJECT="your-project-id"
export AUTH_ID="your-auth-id"
export CLIENT_ID="your-client-id"
export CLIENT_SECRET="your-client-secret"

curl -X POST \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -H "X-Goog-User-Project: $GOOGLE_CLOUD_PROJECT" \
  "https://global-discoveryengine.googleapis.com/v1alpha/projects/$GOOGLE_CLOUD_PROJECT/locations/global/authorizations?authorizationId=$AUTH_ID" \
  -d @- <<EOF
{
  "name": "projects/$GOOGLE_CLOUD_PROJECT/locations/global/authorizations/$AUTH_ID",
  "serverSideOauth2": {
    "clientId": "$CLIENT_ID",
    "clientSecret": "$CLIENT_SECRET",
    "authorizationUri": "https://accounts.google.com/o/oauth2/v2/auth?access_type=offline&prompt=consent&response_type=code&scope=https://www.googleapis.com/auth/bigquery%20https://www.googleapis.com/auth/userinfo.email",
    "tokenUri": "https://oauth2.googleapis.com/token"
  }
}
EOF
```

**Critical**: The `AUTH_ID` here must exactly match `GE_AUTH_ID` in your `.env` file. This is how Gemini Enterprise knows which key to use when passing the access token to the agent via `tool_context`.

## Step 6: Install Dependencies and Deploy

```bash
cd bq-agent-ge
source venv/bin/activate
uv pip install "google-adk>=1.25.0"

# Set your project
export GOOGLE_CLOUD_PROJECT="your-project-id"

./deploy.sh
```

Save the reasoning engine path from the output (e.g., `projects/<project-number>/locations/us-central1/reasoningEngines/<id>`).

## Step 7: Register with Gemini Enterprise

```bash
export GOOGLE_CLOUD_PROJECT="your-project-id"
export GE_APP_ID="your-gemini-enterprise-engine-id"
export GE_AUTH_RESOURCE="projects/<project-number>/locations/global/authorizations/your-auth-id"

./register.sh <reasoning-engine-path-from-step-6>
```

## Step 8: Test

Go to Gemini Enterprise console > Agents > Preview. On first interaction, you'll see the OAuth consent screen. After granting access, ask something like "What datasets exist in my project?"

---

## Gotchas and Troubleshooting

### 1. Model not available (404 NOT_FOUND)

`adk deploy` doesn't validate model availability — you only discover the error at runtime. Check Agent Engine logs:

```bash
gcloud logging read \
  'resource.type="aiplatform.googleapis.com/ReasoningEngine" AND resource.labels.reasoning_engine_id="<ID>"' \
  --project=$GOOGLE_CLOUD_PROJECT --limit=30 --format="json"
```

Use a GA model like `gemini-2.5-flash`. Preview models (e.g., `gemini-3-flash-preview`) may not be enabled in your project.

### 2. Auth resource "used by another agent" (400 FAILED_PRECONDITION)

Each Gemini Enterprise authorization resource can only be linked to **one agent at a time**. Even after deleting an agent, the auth resource may not be immediately released.

**Fix**: Create a new OAuth client + auth resource with a unique ID.

### 3. AUTH_ID must match between agent code and registration

The `external_access_token_key` in `agent.py` must exactly match the authorization resource ID used during Gemini Enterprise registration. Mismatches cause silent failures — the agent deploys and registers fine, but the access token won't be found at runtime.

### 4. OAuth redirect URI mismatch (Error 400: redirect_uri_mismatch)

Gemini Enterprise uses **two** redirect URIs. Add **both** to your OAuth client:
- `https://vertexaisearch.cloud.google.com/static/oauth/oauth.html`
- `https://vertexaisearch.cloud.google.com/oauth-redirect`

Check the error message for the actual `redirect_uri` being used and add it verbatim.

### 5. Each redeploy requires delete → deploy → re-register

Agent Engine doesn't support in-place updates. To change `agent.py`:
1. Unregister from Gemini Enterprise (DELETE the agent)
2. Delete the Agent Engine reasoning engine
3. Redeploy with `adk deploy agent_engine`
4. Re-register with the new reasoning engine path

---

## Configuration Reference

| Component | Value |
|---|---|
| Model | `gemini-2.5-flash` |
| Credential Type | `AuthCredentialTypes.HTTP` |
| Write Mode | `BLOCKED` (read-only) |
| Required OAuth Redirect URIs | `/oauth-redirect` and `/static/oauth/oauth.html` |
| ADK Version | `>= 1.25.0` |
