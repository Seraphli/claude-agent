#!/bin/bash
# Hook event handler for E2E tests
# Reads JSON payload from stdin, appends structured line to event log
PAYLOAD=$(cat)
EVENT=$(echo "$PAYLOAD" | jq -r '.hook_event_name // "unknown"')
TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_name // ""')
TIMESTAMP=$(date '+%s.%3N')

# Append single JSON line to event log (atomic via single echo)
echo "{\"ts\":\"$TIMESTAMP\",\"event\":\"$EVENT\",\"tool_name\":\"$TOOL_NAME\",\"payload\":$PAYLOAD}" >> "$CA_EVENT_LOG"
