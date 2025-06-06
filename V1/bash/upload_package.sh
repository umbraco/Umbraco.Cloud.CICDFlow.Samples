#!/bin/bash

# Set required variables
projectId="$1"
deploymentId="$2"
apiKey="$3"
filePath="$4"

# Not required, defaults to https://api.cloud.umbraco.com
baseUrl="$5" 

if [[ -z "$baseUrl" ]]; then
    baseUrl="https://api.cloud.umbraco.com"
fi

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#upload-zip-source-file
#
url="$baseUrl/v1/projects/$projectId/deployments/$deploymentId/package"

function call_api {
  response=$(curl -s -w "%{http_code}" -X POST $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: multipart/form-data" \
    --form "file=@$filePath")
  responseCode=${response: -3}  
  content=${response%???}

  if [[ 10#$responseCode -eq 202 ]]; then
    echo $content
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
