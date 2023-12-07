#!/bin/bash

# Set variables
baseUrl="$1"
projectId="$2"
deploymentId="$3"
url="$baseUrl/v1/projects/$projectId/deployments/$deploymentId"
apiKey="$4"

# Define function to call API to start thedeployment
function call_api {
  echo "$url"
  response=$(curl --insecure -s -X PATCH $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json" \
    -d "{\"deploymentState\": \"Queued\"}")
  echo "$response"
  # http status 202 expected here
  # extract status for validation
  status=$(echo "$response" | jq -r '.deploymentState')
  if [[ $status != "Queued" ]]; then
    echo "Unexpected status: $status"
    exit 1
  fi
}

call_api

echo "Deployment started successfully -> $deployment_id"
