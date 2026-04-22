import os

from google.adk.agents.llm_agent import LlmAgent
from google.adk.auth.auth_credential import AuthCredentialTypes
from google.adk.tools.bigquery.bigquery_credentials import BigQueryCredentialsConfig
from google.adk.tools.bigquery.bigquery_toolset import BigQueryToolset
from google.adk.tools.bigquery.config import BigQueryToolConfig
from google.adk.tools.bigquery.config import WriteMode

BIGQUERY_AGENT_NAME = "bq_agent_gemini_enterprise"

# Must match the Gemini Enterprise authorization resource ID
AUTH_ID = os.getenv("GE_AUTH_ID", "your-auth-id")

CREDENTIALS_TYPE = AuthCredentialTypes.HTTP

tool_config = BigQueryToolConfig(
    write_mode=WriteMode.BLOCKED,
    application_name=BIGQUERY_AGENT_NAME,
    max_query_result_rows=50,
)

credentials_config = BigQueryCredentialsConfig(
    external_access_token_key=AUTH_ID
)

bigquery_toolset = BigQueryToolset(
    credentials_config=credentials_config, bigquery_tool_config=tool_config
)

root_agent = LlmAgent(
    model="gemini-2.5-flash",
    name=BIGQUERY_AGENT_NAME,
    description=(
        "Agent to answer questions about BigQuery data and execute"
        " SQL queries using end-user credentials via Gemini Enterprise."
    ),
    instruction="""\
        You are a data analytics agent with access to BigQuery tools.
        Use your tools to help users explore datasets, run SQL queries,
        and analyze data in BigQuery.
        Always confirm which project and dataset the user wants to query.
        Present query results in a clear, readable format.
    """,
    tools=[bigquery_toolset],
)
