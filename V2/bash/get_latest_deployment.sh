#!/bin/bash

# Set required variables
projectId="$1"
apiKey="$2"
targetEnvironmentAlias="$3"
pipelineVendor="$4"

# Not required, defaults to https://api.cloud.umbraco.com
baseUrl="$5"

if [[ -z $baseUrl ]]; then
    baseUrl="https://api.cloud.umbraco.com"
fi

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi/todo-v2
#
# We want the Id of the latest deployment that created changes to cloud 
# Filter deployments
skip=0
take=1
# Exclude cloud null deployments
includeNullDeployments=false

queryString="take=$take&skip=$skip&includenulldeployments=$includeNullDeployments&targetEnvironmentAlias=$targetEnvironmentAlias"

url="$baseUrl/v2/projects/$projectId/deployments?$queryString"

function call_api {
  response=$(curl -s -w "%{http_code}" -X GET $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json")
    responseCode=${response: -3}  
    content=${response%???}
  cat "content"
  if [[ 10#$responseCode -eq 200 ]]; then
    latestDeploymentId=$(echo $content | jq -Rnr '[inputs] | join("\\n") | fromjson | .data[0].id')

    if [[ -z $latestDeploymentId || $latestDeploymentId == null ]]; then
        echo "No latest CICD Flow Deployments found"
        echo "----------------------------------------------------------------------------------------"
        echo "This is usually because you have yet to make changes to cloud through the CICD endpoints"
        latestDeploymentId=''
    else 
        echo "Latest CICD Flow Deployment:"
        echo "$latestDeploymentId"
    fi

    return
  fi

  ## Let errors bubble forward 
  errorResponse=$response
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

## Write the latest deployment id to the pipelines variables for use in a later step
if [[ "$pipelineVendor" == "GITHUB" ]]; then
  echo "latestDeploymentId=$latestDeploymentId" >> "$GITHUB_OUTPUT"
  exit 0
elif [[ "$pipelineVendor" == "AZUREDEVOPS" ]]; then
  echo "##vso[task.setvariable variable=latestDeploymentId;isOutput=true]$latestDeploymentId"
  echo "##vso[task.setvariable variable=latestDeploymentId]$latestDeploymentId"

  exit 0
elif [[ "$pipelineVendor" == "TESTRUN" ]]; then
  echo $pipelineVendor
  exit 0
fi

echo "Please use one of the supported Pipeline Vendors or enhance script to fit your needs"
echo "Currently supported are: GITHUB and AZUREDEVOPS"
exit 1
