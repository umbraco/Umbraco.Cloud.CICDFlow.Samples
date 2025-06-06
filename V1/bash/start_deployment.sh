#!/bin/bash

# Set variables
projectId="$1"
deploymentId="$2"
apiKey="$3"

# Not required, defaults to https://api.cloud.umbraco.com
baseUrl="$4" 

if [[ -z "$baseUrl" ]]; then
    baseUrl="https://api.cloud.umbraco.com"
fi

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#start-deployment
#
url="$baseUrl/v1/projects/$projectId/deployments/$deploymentId"

# Define function to call API to start thedeployment
function call_api {
  echo "Requesting start Deployment at $url"
  response=$(curl -s -w "%{http_code}" -X PATCH $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json" \
    -d "{\"deploymentState\": \"Queued\"}")

  responseCode=${response: -3}  
  content=${response%???}

  if [[ 10#$responseCode -eq 202 ]]; then
    updateMessage=$(echo "$response" | jq -r '.updateMessage')
    echo "Deployment started successfully -> $deployment_id"
    echo $updateMessage
    exit 0
  fi

  ## Let errors bubble forward 
  echo "Unexpected API Response Code: $responseCode"
  echo "---Response Start---"
  echo $content
  echo "---Response End---"
  exit 1
}

call_api

