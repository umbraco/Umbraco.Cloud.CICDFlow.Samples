# Set variables
param(
    [Parameter(Position=0)]    
    [string] 
    $ProjectId,

    [Parameter(Position=1)]
    [string] 
    $ApiKey,

    [Parameter(Position=2)]
    [string] 
    $TargetEnvironmentAlias,

    [Parameter(Position=3)]
    [string] 
    $PipelineVendor, ## GITHUB or AZUREDEVOPS

    [Parameter(Position=4)]    
    [string] 
    $BaseUrl = "https://api.cloud.umbraco.com"
)

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi/todo-v2
#
# We want the Id of the latest deployment that created changes to cloud 
# Filter deployments
$Skip = 0
$Take = 1
# Exclude cloud null deployments
$IncludeNullDeployments = $False


$DeploymentUrl = "$BaseUrl/v2/projects/$ProjectId/deployments?skip=$Skip&take=$Take&includenulldeployments=$IncludeNullDeployments&targetEnvironmentAlias=$TargetEnvironmentAlias"

$Headers = @{
  'Umbraco-Cloud-Api-Key' = $ApiKey
  'Content-Type' = 'application/json'
}

# Actually calling the endpoint
try{
    $Response = Invoke-WebRequest -URI $DeploymentUrl -Headers $Headers 

    if ($Response.StatusCode -eq 200) {
        
        $JsonResponse = ConvertFrom-Json $([String]::new($Response.Content))

        $latestDeploymentId = ''

        if ($JsonResponse.data.Count -gt 0){
            
            $latestDeploymentId = $JsonResponse.data[0].id
        }

        ## Write the latest deployment id to the pipelines variables for use in a later step
        switch ($PipelineVendor) {
            "GITHUB" {
                "latestDeploymentId=$($latestDeploymentId)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
            }
            "AZUREDEVOPS" {
                Write-Host "##vso[task.setvariable variable=latestDeploymentId;isOutput=true]$($latestDeploymentId)"
                Write-Host "##vso[task.setvariable variable=latestDeploymentId]$($latestDeploymentId)"

            }
            "TESTRUN" {
                Write-Host $PipelineVendor
            }
            Default {
                Write-Host "Please use one of the supported Pipeline Vendors or enhance script to fit your needs"
                Write-Host "Currently supported are: GITHUB and AZUREDEVOPS"
                Exit 1
            }
        }

        if ($latestDeploymentId -eq '') {
            Write-Host "No latest CICD Flow Deployments found"
            Write-Host "----------------------------------------------------------------------------------------"
            Write-Host "This is usually because you have yet to make changes to cloud through the CICD endpoints"
        }
        else {
            Write-Host "Latest CICD Flow Deployment:"
            Write-Host "$($latestDeploymentId)"
        }
        exit 0
    }
    ## Let errors bubble forward 
    Write-Host "---Response Start---"
    Write-Host $Response
    Write-Host "---Response End---"
    Write-Host "Unexpected response - see above"
    exit 1
}
catch {
  Write-Host "---Error---"
  Write-Host "Exception Message: $($_.Exception.Message)"
  
  if ($_.ErrorDetails) {
      Write-Host "API Error Response: $($_.ErrorDetails.Message)"
  }
  
  if ($_.Exception.Response) {
      $statusCode = $_.Exception.Response.StatusCode.value__
      Write-Host "HTTP Status Code: $statusCode"
  }
  
  exit 1
}