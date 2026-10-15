#!/usr/bin/env bash
# Connects the DEV Fabric workspace to github.com/janjuas/Analytics-Projects, folder
# /Retail-Promotions-Analytics/fabric on main, and commits the existing workspace items
# (lakehouses, warehouse, notebooks, dbt job) into Git.
#
# Prerequisites (see README "Connect GitHub"):
#   1. Retail-Promotions-Analytics/fabric exists on `main`.
#   2. A Fabric "GitHub - Source control" connection exists (Settings > Manage connections and gateways),
#      created with a fine-grained PAT that has Contents: Read and write on Analytics-Projects.
#   3. Tenant setting "Users can sync workspace items with GitHub repositories" is enabled.
#
# Usage: bash infra/connect_git.sh <fabric-connection-id> [github-owner] [repo-name]
set -euo pipefail

CONN=${1:?fabric connection id}; OWNER=${2:-janjuas}; REPO=${3:-Analytics-Projects}
DIR=/Retail-Promotions-Analytics/fabric
API=https://api.fabric.microsoft.com/v1
RES=https://api.fabric.microsoft.com
WS=b012dc67-8617-4001-9e2c-87ca2d1c24ca

fab() { az rest --resource "$RES" --headers "Content-Type=application/json" "$@"; }

echo "Connecting workspace to github.com/$OWNER/$REPO (main:$DIR)..."
fab --method post --url "$API/workspaces/$WS/git/connect" -o none --body "{
  \"gitProviderDetails\": {
    \"gitProviderType\": \"GitHub\",
    \"ownerName\": \"$OWNER\",
    \"repositoryName\": \"$REPO\",
    \"branchName\": \"main\",
    \"directoryName\": \"$DIR\"
  },
  \"myGitCredentials\": {\"source\": \"ConfiguredConnection\", \"connectionId\": \"$CONN\"}
}"

INIT=$(fab --method post --url "$API/workspaces/$WS/git/initializeConnection" \
  --body '{"initializationStrategy": "PreferWorkspace"}' -o json)
echo "$INIT"
ACTION=$(echo "$INIT" | python -c "import sys,json;print(json.load(sys.stdin).get('requiredAction',''))")
HEAD=$(echo "$INIT" | python -c "import sys,json;print(json.load(sys.stdin).get('workspaceHead') or '')")

if [[ "$ACTION" == "CommitToGit" ]]; then
  fab --method post --url "$API/workspaces/$WS/git/commitToGit" -o none --body "{
    \"mode\": \"All\", \"workspaceHead\": \"$HEAD\",
    \"comment\": \"Initial commit of Fabric workspace items\"}"
  echo "Committed workspace items to $OWNER/$REPO main:$DIR"
elif [[ "$ACTION" == "UpdateFromGit" ]]; then
  echo "Repo folder already has content - run 'Update all' from the workspace Source control panel."
fi

fab --method get --url "$API/workspaces/$WS/git/status" --query "{workspaceHead:workspaceHead, remoteCommitHash:remoteCommitHash, changes:length(changes)}" -o json
