#!/usr/bin/env bash
# Creates the dev -> prod Fabric deployment pipeline and assigns the two workspaces.
# Idempotent: reuses the pipeline if one with the same name already exists.
# Requires: az login (account with Admin on both workspaces).
set -euo pipefail

API=https://api.fabric.microsoft.com/v1
RES=https://api.fabric.microsoft.com
NAME="dunnhumby-promo"
DEV_WS=b012dc67-8617-4001-9e2c-87ca2d1c24ca
PROD_WS=9da73741-81f4-4edc-a1c0-33045a507804

fab() { az rest --resource "$RES" --headers "Content-Type=application/json" "$@"; }

PIPELINE_ID=$(fab --method get --url "$API/deploymentPipelines" --query "value[?displayName=='$NAME'].id | [0]" -o tsv)
if [[ -z "$PIPELINE_ID" ]]; then
  PIPELINE_ID=$(fab --method post --url "$API/deploymentPipelines" --body "{
    \"displayName\": \"$NAME\",
    \"description\": \"Promote dunnhumby promotions analytics items from dev to prod.\",
    \"stages\": [
      {\"displayName\": \"Development\", \"description\": \"Git-connected dev workspace\", \"isPublic\": false},
      {\"displayName\": \"Production\",  \"description\": \"Prod workspace, deploy-only\",  \"isPublic\": false}
    ]}" --query id -o tsv)
  echo "Created pipeline $PIPELINE_ID"
else
  echo "Reusing pipeline $PIPELINE_ID"
fi

mapfile -t STAGES < <(fab --method get --url "$API/deploymentPipelines/$PIPELINE_ID/stages" --query "sort_by(value, &order)[].id" -o tsv | tr -d '\r')

assign() {
  local stage=$1 ws=$2
  local current
  current=$(fab --method get --url "$API/deploymentPipelines/$PIPELINE_ID/stages/$stage" --query "workspaceId" -o tsv 2>/dev/null || true)
  if [[ "$current" == "$ws" ]]; then echo "Stage $stage already has $ws"; return; fi
  fab --method post --url "$API/deploymentPipelines/$PIPELINE_ID/stages/$stage/assignWorkspace" --body "{\"workspaceId\": \"$ws\"}" -o none
  echo "Assigned $ws to stage $stage"
}
assign "${STAGES[0]}" "$DEV_WS"
assign "${STAGES[1]}" "$PROD_WS"

fab --method get --url "$API/deploymentPipelines/$PIPELINE_ID/stages" \
  --query "value[].{order:order, stage:displayName, workspace:workspaceName, id:id}" -o table
