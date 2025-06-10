#!/bin/bash

# Set required variables
projectId="$1"
apiKey="$2"
filePath="$3"
description="$4"
version="$5"
pipelineVendor="$6"

# Not required, defaults to https://api.cloud.umbraco.com
baseUrl="$7" 

if [[ -z "$baseUrl" ]]; then
    baseUrl="https://api.cloud.umbraco.com"
fi

if [[ -z "$filePath" ]]; then
  echo "filePath is empty"
  exit 1
fi

if [[ ! -f "$filePath" ]]; then
  echo "filePath does not contain a file"
  exit 1
fi

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi/todo-v2
#
url="$baseUrl/v2/projects/$projectId/deployments/artifacts"

function call_api {
  response=$(curl -s -w "%{http_code}" -X POST $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -F "file=@$filePath" \
    -F "description=$description" \
    -F "version=$version")

  responseCode=${response: -3}  
  content=${response%???}
  artifact_id=$(echo "$content" | jq -r '.artifactId')

  if [[ 10#$responseCode -eq 200 ]]; then
    ## Write the latest deployment id to the pipelines variables for use in a later step
    if [[ "$pipelineVendor" == "GITHUB" ]]; then
      echo "artifactId=$artifact_id" >> "$GITHUB_OUTPUT"
    elif [[ "$pipelineVendor" == "AZUREDEVOPS" ]]; then
      echo "##vso[task.setvariable variable=artifactId;isOutput=true]$artifact_id"
    elif [[ "$pipelineVendor" == "TESTRUN" ]]; then
      echo $pipelineVendor
    else
      echo "Please use one of the supported Pipeline Vendors or enhance script to fit your needs"
      echo "Currently supported are: GITHUB and AZUREDEVOPS"
      exit 1
    fi

    echo "Artifact uploaded - Artifact Id: $artifact_id"
    echo "--- Upload Response ---"
    cat "$content"

    exit 0
  fi

  ## Let errors bubble forward 
  errorResponse=$content
  echo "Unexpected API Response Code: $responseCode - More details below"
  # Check if the input is valid JSON
  cat "$errorResponse" | jq . > /dev/null 2>&1
  if [ $? -ne 0 ]; then
      echo "--- Response RAW ---\n"
      cat "$errorResponse"
  else 
      echo "--- Response JSON formatted ---"
      cat "$errorResponse" | jq .
  fi
  echo "---Response End---"
  exit 1
}

call_api
