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
    $DeploymentId, 

    [Parameter(Position=3)]
    [string] 
    $TargetEnvironmentAlias,

    [Parameter(Position=4)]
    [string]
    $DownloadFolder,

    [Parameter(Position=5)]
    [string] 
    $PipelineVendor, ## GITHUB or AZUREDEVOPS

    [Parameter(Position=6)]    
    [string] 
    $BaseUrl = "https://api.cloud.umbraco.com"
)

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi/todo-v2
#
$ChangeUrl = "$BaseUrl/v2/projects/$ProjectId/deployments/$DeploymentId/diff?targetEnvironmentAlias=$TargetEnvironmentAlias"

$Headers = @{
  'Umbraco-Cloud-Api-Key' = $ApiKey
  'Content-Type' = 'application/json'
}

if ($GetDiffDeploymentId -eq '') {
    Write-Host "I need a DeploymentId of an older deployment to download a git-patch"
    Exit 1;
}

# ensure folder exists
if (!(Test-Path $DownloadFolder -PathType Container)) { 
  Write-Host "Creting folder $($DownloadFolder)"
  New-Item -ItemType Directory -Force -Path $DownloadFolder
}

try {
  $Response = Invoke-WebRequest -URI $ChangeUrl -Headers $Headers
  $StatusCode = $Response.StatusCode
  
  switch ($StatusCode){
    "204" {
      Write-Host "No Changes - You can continue"
      $remoteChanges = "no"
    }
    "200" {
      Write-Host "Changes detected"
      $Response | Select-Object -ExpandProperty Content | Out-File "$DownloadFolder/git-patch.diff"
      $remoteChanges = "yes"
    }
    Default {
      Write-Host "---Response Start---"
      Write-Host $Response
      Write-Host "---Response End---"
      Write-Host "Unexpected response - see above"
      exit 1
    }
  }

  switch ($PipelineVendor) {
    "GITHUB" {
      "remoteChanges=$($remoteChanges)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    }
    "AZUREDEVOPS" {
        Write-Host "##vso[task.setvariable variable=remoteChanges;isOutput=true]$($remoteChanges)"
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
  Exit 0
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