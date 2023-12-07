#!/bin/bash

# Set variables
baseUrl="$1"
projectId="$2"
deploymentId="$3"
url="$baseUrl/v1/projects/$projectId/deployments/$deploymentId/package"
apiKey="$4"
file="$5"

function call_api {
  response=$(curl --insecure -s -X POST $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: multipart/form-data" \
    --form "file=@$file")

  echo "$response"
}

call_api
