---
name: debug-appinsights
description: Query Azure Application Insights for exceptions, failed requests, custom events, and traces. Supports per-app custom workflows like latency analysis and gRPC debugging.
argument-hint: <app> [env] [--since duration] [--workflow name]
---

# Debug App Insights

Query Azure Application Insights and present structured diagnostics for analysis.

## Input

The user invokes with: `/debug-appinsights [app] [env] [--since duration] [--workflow name]`

Examples:
- `/debug-appinsights runtime prod --since 30m`
- `/debug-appinsights ai1099 dev-api --since 2h --workflow grpc`
- `/debug-appinsights runtime` (uses default env from config)
- `/debug-appinsights` (lists available apps)

## Process

### Step 1: Parse Arguments

Extract from the user's input:
- **app**: The application name (e.g., `runtime`, `ai1099`)
- **env**: The environment name (e.g., `prod`, `dev`, `prod-api`). Optional — uses `default_env` from config if omitted.
- **--since**: Time window (e.g., `30m`, `1h`, `2h`). Optional — defaults to `1h`.
- **--workflow**: Name of a custom workflow defined in the app config. Optional.

### Step 2: Interactive Setup (if parameters are missing)

If the user invoked `/debug-appinsights` with no arguments or partial arguments, walk them through the choices interactively using `AskUserQuestion`. Read the configs first so you can present real options.

**If no app was specified:**

1. Use Glob to find all `config/appinsights/*.yaml` files (excluding `example.yaml`), then Read each to get `app`, `description`, and the list of environments and workflows.
2. Use `AskUserQuestion` to ask which app:
   - Options should be the available apps with their descriptions (e.g., "runtime" — "Runtime API — search engine and API layer")

**After the app is known, if env or workflow are missing:**

3. Read the selected app's config file. Use `AskUserQuestion` to ask up to 3 questions in a single call:
   - **Environment**: Which environment? Options from the config's `environments` keys (e.g., "prod", "ppe", "dev", "search-prod"). Mark the `default_env` as "(Recommended)". Include the description if the env has a `resource_type` override (e.g., "search-prod — Azure Search").
   - **Workflow**: What do you want to look at? Options: "Standard diagnostics (exceptions, failed requests, traces)" as first option, then each named workflow from the config with its `description`. Use `multiSelect: false`.
   - **Time window**: How far back? Options: "30m", "1h (Recommended)", "2h", "6h".

**If all parameters were provided on the command line**, skip the interactive setup entirely and proceed to Step 3.

### Step 3: Read Config

Use the Read tool to load `config/appinsights/<app>.yaml`. Extract:
- `environments.<env>.subscription`
- `environments.<env>.resource_group`
- `environments.<env>.resource`
- `environments.<env>.resource_type` (optional — defaults to `Microsoft.Insights/components` for App Insights. Use `Microsoft.Search/searchServices` for Azure Search environments.)
- `workflows.<name>.kql` (if a workflow was selected)
- `workflows.<name>.description` (if a workflow was selected)

If the env doesn't exist in the config, show available environments and ask the user to pick one.

### Step 4: Check Dependencies

Run via Bash:
```
pip install -r scripts/appinsights/requirements.txt --quiet 2>/dev/null || pip install -r scripts/appinsights/requirements.txt
```

This is idempotent — safe to run every time.

### Step 5: Run the Query Script

Build the command from the resolved config values and run via Bash:

```bash
python scripts/appinsights/query.py \
  --subscription "<subscription>" \
  --resource-group "<resource_group>" \
  --resource "<resource>" \
  --since "<since>" \
  --max-results 50
```

If the environment has a `resource_type` field (e.g., Azure Search), also add:
```bash
  --resource-type "<resource_type>"
```

If a `--workflow` was specified: write the KQL to a temp file first, then pass it via `--workflow-kql-file`. This avoids bash escaping issues with characters like `!=` in KQL:
```bash
# Write KQL to temp file (avoids bash mangling of !=, |, etc.)
cat > /tmp/workflow.kql << 'ENDKQL'
<kql from config>
ENDKQL

python scripts/appinsights/query.py \
  ... \
  --workflow-kql-file /tmp/workflow.kql \
  --workflow-name "<workflow name>"
```

**Important for non-App-Insights resources** (e.g., Azure Search with `resource_type: Microsoft.Search/searchServices`): The default queries (exceptions, failed-requests, custom-events, traces) are App Insights-specific tables and won't exist on other resource types. When querying a non-App-Insights resource, pass `--queries ""` to skip the defaults and only run the workflow query.

### Step 6: Analyze Results

Read the script's stdout output and provide analysis. **IMPORTANT: Always include the Azure Portal deep links from the script output in your analysis.** Every section the script outputs contains an `[Open in Azure Portal](...)` link — you MUST reproduce these links in your response so the engineer can click through to explore further. Format them clearly next to each section heading or finding.

1. **If exceptions were found**: Group by type, identify the most impactful (highest count, most recent), and suggest investigation steps. Include the portal link for the exceptions query and each detail query. Example: "The top exception is `NullReferenceException` in `SearchController.Execute` ([Open in Portal](link)) — want me to look at that code?"

2. **If failed requests were found**: Highlight endpoints with high failure rates or slow response times. Correlate with exceptions if they share operation names. Include the portal link.

3. **If custom events look unusual**: Flag events with unexpectedly high or low counts compared to normal patterns. Include the portal link.

4. **If traces show errors**: Connect trace errors to exceptions or failed requests. Include the portal link.

5. **If nothing was found**: Say so clearly: "No exceptions or failed requests in the last {window}. Looks healthy." Still include the portal links so the engineer can verify.

6. **For custom workflows**: Present the workflow results and interpret them. For latency, highlight endpoints with high P99. For gRPC, highlight high failure rates. Include the portal link.

### Step 7: Suggest Next Steps

Based on findings, suggest actionable next steps:
- "Want me to look at the code for `SearchController`?" (if exceptions point to specific code)
- "The P99 latency for `/api/search` is 5.2s — want to run the latency workflow for a longer window?"
- "There are gRPC failures to `profile-service` — want me to check that service's App Insights too?"
- "Want me to open the Azure Portal link to explore further?"

### Alternate Flow: Parse an Alert or Portal URL

When the user shares an Azure Portal URL (from an alert email, Slack thread, or browser), parse it to extract the resource and KQL query before running diagnostics.

**Recognizing portal URLs**: Any URL containing `portal.azure.com` with `/blade/Microsoft_Azure_Monitoring_Logs/LogsBlade/` is a Logs blade link. Alert emails and Slack messages often contain these.

**Step A: Decode the URL**

Run via Bash:
```bash
python scripts/appinsights/query.py --parse-url "<portal_url>"
```

This outputs the decoded resource info (subscription, resource group, resource name, resource type) and the KQL query in readable form. The script handles two encoding formats:
- **URL-encoded KQL** in `/query/<encoded>/` — our portal deep links use this format
- **Gzip+base64 encoded KQL** in `/q/<encoded>/` — Azure Portal "Share" links and alert URLs use this format

**Step B: Match to a known config**

Check if the decoded resource matches an environment in any `config/appinsights/*.yaml` file. If it does, you can use the existing config for further queries. If not, you can still run queries using the extracted subscription/resource-group/resource directly.

**Step C: Run the extracted query or standard diagnostics**

Two options:
1. **Run the extracted KQL as a workflow**: Write the decoded KQL to a temp file and run it as a custom workflow against the extracted resource.
2. **Run standard diagnostics**: Use the extracted resource info to run the full default query set (exceptions, failed requests, etc.) for broader context.

Example flow for an alert URL:
```bash
# Decode the URL
python scripts/appinsights/query.py --parse-url "https://portal.azure.com/#@seekout.com/blade/..."

# Run the extracted KQL against the resource
cat > /tmp/alert-query.kql << 'ENDKQL'
<decoded KQL from parse output>
ENDKQL

python scripts/appinsights/query.py \
  --subscription "<from parse output>" \
  --resource-group "<from parse output>" \
  --resource "<from parse output>" \
  --resource-type "<from parse output if not App Insights>" \
  --since "1h" \
  --queries "" \
  --workflow-kql-file /tmp/alert-query.kql \
  --workflow-name "Alert Query"
```

## Error Handling

- **Auth failure**: Tell the user to run `az login --tenant seekout.com` and try again.
- **Resource not found**: Show the exact subscription/RG/resource from config and suggest checking if the values are correct.
- **Script not found**: Tell the user the script is at `scripts/appinsights/query.py` and suggest checking the path.
- **Config not found**: Tell the user to create a config file at `config/appinsights/<app>.yaml` using `example.yaml` as a template.

## Important Notes

- Always show the Azure Portal deep links from the output — engineers frequently want to click through and explore.
- The script output is structured markdown. Present it directly, then add your analysis after.
- If querying multiple environments (e.g., comparing prod vs dev), run the script twice with different parameters.
- Custom workflow KQL uses `{timeWindow}` as a placeholder — the script handles the replacement.

## Known Issues and Learnings

These were discovered during implementation and testing. Keep them in mind when debugging issues with the skill.

### Authentication
- **ManagedIdentityCredential crash**: On dev machines with Azure Connected Machine Agent, `ManagedIdentityCredential` throws `[WinError 5] Access is denied` which breaks the entire `DefaultAzureCredential` chain before `AzureCliCredential` gets a chance to run. The script excludes it with `exclude_managed_identity_credential=True`.
- **Auth error noise**: `DefaultAzureCredential` is lazy — without a preflight check, the same auth failure repeats for every query. The script does a preflight `credential.get_token()` call to fail fast with a clear message.
- **Token scope**: The Log Analytics API scope is `https://api.loganalytics.io/.default`. This works for both App Insights and Azure Search diagnostics.

### Portal Deep Links
- **URL-encoding, NOT base64**: Portal deep links must use `urllib.parse.quote(kql)` in the `/query/` segment. Base64-encoded KQL gets dumped as literal text into the Logs blade editor and doesn't execute. This was verified in Chrome.
- **Share link format is different**: Azure Portal's "Share" button generates gzip+base64 encoded KQL in a `/q/` segment (sometimes JSON-wrapped as `{"query": "..."}`). The `--parse-url` mode handles both formats.
- **Alert email URLs**: Alert URLs from Azure Monitor emails use the same gzip+base64 format as Share links.

### Azure SDK Quirks
- **Column names are plain strings**: `table.columns` from `azure-monitor-query` returns plain strings, not objects with a `.name` attribute. Use `hasattr(col, "name")` to handle both cases.
- **Flattened column names**: The SDK flattens nested fields like `details[0].rawStack` to `details_0_rawStack`. Check both naming conventions when accessing exception stack traces.
- **`query_resource()` not `query_workspace()`**: Use `query_resource()` with the full ARM resource ID path, not `query_workspace()` with a workspace ID. This is the correct approach for App Insights resources.

### Azure Search (AzureDiagnostics)
- **Different timestamp column**: Azure Search diagnostics use `TimeGenerated` (not `timestamp` as in App Insights tables).
- **Column names have no type suffix**: Despite some documentation suggesting `DurationMs_d` or `Documents_d`, the actual column names are `DurationMs`, `Documents_d`, `IndexName_s`, `Query_s`, etc. Test against the actual resource to confirm.
- **Percentile requires `toreal()` cast**: `percentile(DurationMs, 50)` fails because `DurationMs` may be a string type in `AzureDiagnostics`. Use `percentile(toreal(DurationMs), 50)`.
- **Default queries don't apply**: The App Insights tables (`exceptions`, `requests`, `customEvents`, `traces`) don't exist on Azure Search resources. Always pass `--queries ""` to skip defaults when querying non-App-Insights resources.

### Bash Escaping
- **`!=` in KQL breaks bash**: The `!` character triggers bash history expansion even inside single quotes in some shell configurations. Always write KQL to a temp file via heredoc and use `--workflow-kql-file` instead of passing KQL directly on the command line.
- **Heredoc quoting**: Use `<< 'ENDKQL'` (quoted delimiter) to prevent bash from interpreting variables and special characters inside the KQL.

### KQL Gotchas
- **`split()` returns dynamic type**: The result of `split(message, " ")` is a dynamic array. Indexing it (`parsedStrings[N]`) returns a dynamic value that can't be used directly in `summarize by`. Wrap with `tostring()`.
- **`substring()` for truncation**: Use `substring(field, 0, 200)` in KQL to truncate long strings (URLs, messages) to prevent huge result sets.
