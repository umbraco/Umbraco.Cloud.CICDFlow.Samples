#!/bin/bash

# Set variables
projectId="$1"
apiKey="$2"
artifactId="$3"
targetEnvironmentAlias="$4"
commitMessage="$5"
noBuildAndRestore="${6:-false}"
skipVersionCheck="${7:-false}"
allowAnyTarget="${8:-false}"
pipelineVendor="$9"

# Not required, defaults to https://api.cloud.umbraco.com
baseUrl="${10:-https://api.cloud.umbraco.com}" 


### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi/todo-v2
#
url="$baseUrl/v2/projects/$projectId/deployments"

# Define function to call API to start thedeployment
function call_api {
  echo "Requesting start Deployment at $url with options:"
  echo " - targetEnvironmentAlias: $targetEnvironmentAlias"
  echo " - artifactId: $artifactId"
  echo " - commitMessage: $commitMessage"
  echo " - noBuildAndRestore: $noBuildAndRestore"
  echo " - skipVersionCheck: $skipVersionCheck"
  echo " - allowAnyTarget: $allowAnyTarget"

  response=$(curl -s -w "%{http_code}" -X POST $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json" \
    -d "{\"targetEnvironmentAlias\": \"$targetEnvironmentAlias\",\"artifactId\": \"$artifactId\",\"commitMessage\": \"$commitMessage\",\"noBuildAndRestore\": $noBuildAndRestore,\"skipVersionCheck\": $skipVersionCheck,\"allowAnyTarget\": $allowAnyTarget}")

  responseCode=${response: -3}  
  content=${response%???}

  echo "--- --- ---"
  echo "Response:"
  echo $content

  if [[ 10#$responseCode -eq 201 ]]; then
    deployment_id=$(echo "$content" | jq -r '.deploymentId')

    if [[ "$pipelineVendor" == "GITHUB" ]]; then
      echo "deploymentId=$deployment_id" >> "$GITHUB_OUTPUT"
    elif [[ "$pipelineVendor" == "AZUREDEVOPS" ]]; then
      echo "##vso[task.setvariable variable=deploymentId;isOutput=true]$deployment_id"
    elif [[ "$pipelineVendor" == "TESTRUN" ]]; then
      echo $pipelineVendor
    else
      echo "Please use one of the supported Pipeline Vendors or enhance script to fit your needs"
      echo "Currently supported are: GITHUB and AZUREDEVOPS"
      exit 1
    fi

    echo "--- --- ---"
    echo "Deployment started successfully -> $deployment_id"
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
      echo "--- Response JSON formatted ---\n"
      cat "$errorResponse" | jq .
  fi
  echo "\n---Response End---"
  exit 1
}

call_api

