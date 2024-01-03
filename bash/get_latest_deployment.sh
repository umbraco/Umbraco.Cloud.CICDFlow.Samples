#!/bin/bash

# Set required variables
projectId="$1"
apiKey="$2"
pipelineVendor="$3"

# Not required, defaults to https://api.cloud.umbraco.com
baseUrl="$4"

if [[ -z $baseUrl ]]; then
    baseUrl="https://api.cloud.umbraco.com"
fi

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#get-deployments
#
# We want the Id of the latest deployment that created changes to cloud 
# Filter deployments
skip=0
take=1
# Exclude cloud null deployments
includeNullDeployments=false

queryString="take=$take&skip=$skip&includenulldeployments=$includeNullDeployments"

url="$baseUrl/v1/projects/$projectId/deployments?$queryString"

function call_api {
  response=$(curl -s -w "%{http_code}" -X GET $url \
    -H "Umbraco-Cloud-Api-Key: $apiKey" \
    -H "Content-Type: application/json")
    responseCode=${response: -3}  
    content=${response%???}

  if [[ 10#$responseCode -eq 200 ]]; then
    latestDeploymentId=$(echo $content | jq -Rnr '[inputs] | join("\\n") | fromjson | .deployments[0].deploymentId')

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
  echo "Unexpected API Response Code: $responseCode"
  echo "---Response Start---"
  echo $response
  echo "---Response End---"

  exit 1
}

call_api

## Write the latest deployment id to the pipelines variables for use in a later step
if [[ "$pipelineVendor" == "GITHUB" ]]; then
  echo "latestDeploymentId=$latestDeploymentId" >> "$GITHUB_OUTPUT"
  exit 0
elif [[ "$pipelineVendor" == "AZUREDEVOPS" ]]; then
  echo "##vso[task.setvariable variable=latestDeploymentId;isOutput=true]$latestDeploymentId"
  exit 0
elif [[ "$pipelineVendor" == "TESTRUN" ]]; then
  echo $pipelineVendor
  exit 0
fi

echo "Please use one of the supported Pipeline Vendors or enhance script to fit your needs"
echo "Currently supported are: GITHUB and AZUREDEVOPS"
Exit 1
