#!/bin/bash

# Set required variables
projectId="$1"
apiKey="$2"
commitMessage="$3"
pipelineVendor="$4"

# Not required, defaults to https://api.cloud.umbraco.com
baseUrl="$5" 

if [[ -z "$baseUrl" ]]; then
    baseUrl="https://api.cloud.umbraco.com"
fi

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#create-the-deployment
#
url="$baseUrl/v1/projects/$projectId/deployments"

# Define function to call API to create a new deployment
function call_api {
  echo "Posting to $url with commit message: $commitMessage"
  response=$(curl -s -w "%{http_code}" -X POST $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json" \
    -d "{\"commitMessage\":\"$commitMessage\"}")
  responseCode=${response: -3}  
  content=${response%???}

  if [[ 10#$responseCode -eq 201 ]]; then
    # extract status and deploymentId for validation and later use
    status=$(echo "$content" | jq -r '.deploymentState')
    deployment_id=$(echo "$content" | jq -r '.deploymentId')
    if [[ "$status" -eq "Created" ]]; then
      return
    fi
  fi

  ## Let errors bubble forward 
  echo "Unexpected API Response Code: $responseCode"
  echo "---Response Start---"
  echo $content
  echo "---Response End---"
  exit 1
}

call_api

echo "Deployment created successfully => $deployment_id"

## Write the latest deployment id to the pipelines variables for use in a later step
if [[ "$pipelineVendor" == "GITHUB" ]]; then
  echo "deploymentId=$deployment_id" >> "$GITHUB_OUTPUT"
  exit 0
elif [[ "$pipelineVendor" == "AZUREDEVOPS" ]]; then
  echo "##vso[task.setvariable variable=deploymentId]$deployment_id"
  exit 0
elif [[ "$pipelineVendor" == "TESTRUN" ]]; then
  echo $pipelineVendor
  exit 0
fi

echo "Please use one of the supported Pipeline Vendors or enhance script to fit your needs"
echo "Currently supported are: GITHUB and AZUREDEVOPS"
Exit 1
