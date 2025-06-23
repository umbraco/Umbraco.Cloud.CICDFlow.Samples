param(
    [Parameter(Position=0)]
    [string] 
    $ProjectId,

    [Parameter(Position=1)]
    [string] 
    $ApiKey,

    [Parameter(Position=2)]
    [string] 
    $ArtifactId,

    [Parameter(Position=3)]
    [string] 
    $TargetEnvironmentAlias,

    [Parameter(Position=4)]
    [string] 
    $CommitMessage = "",
  
    [Parameter(Position=5)]
    [bool] 
    $NoBuildAndRestore = $false,

    [Parameter(Position=6)]
    [bool] 
    $SkipVersionCheck = $false,

    [Parameter(Position=7)]
    [string] 
    $PipelineVendor, ## GITHUB or AZUREDEVOPS

    [Parameter(Position=8)]    
    [string] 
    $BaseUrl = "https://api.cloud.umbraco.com"
)

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi/todo-v2
#
$url = "$BaseUrl/v2/projects/$ProjectId/deployments"

$headers = @{
    'Umbraco-Cloud-Api-Key' = $ApiKey
    'Content-Type' = 'application/json'
}

$requestBody = @{
    'targetEnvironmentAlias' = $TargetEnvironmentAlias
    'artifactId' = $ArtifactId
    'commitMessage' = $CommitMessage
    'noBuildAndRestore' = $NoBuildAndRestore
    'skipVersionCheck' = $SkipVersionCheck
} | ConvertTo-Json

try {
    Write-Host "Requesting start Deployment at $url with Request:"
    $requestBody | Write-Output
    
    $response = Invoke-RestMethod -URI $url -Headers $headers -Method POST -Body $requestBody
    $deploymentId = $response.deploymentId

    Write-Host "--- --- ---"
    Write-Host "Response:"
    $response | ConvertTo-Json -Depth 10 | Write-Output

    switch ($PipelineVendor) {
        "GITHUB" {
            "deploymentId=$($deploymentId)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        }
        "AZUREDEVOPS" {
            Write-Host "##vso[task.setvariable variable=deploymentId;isOutput=true]$($deploymentId)"
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

    Write-Host "--- --- ---"
    Write-Host "Deployment Created Successfully => $($deploymentId)"
    exit 0

    Write-Host "---Response Start---"
    Write-Host $response
    Write-Host "---Response End---"
    Write-Host "Unexpected response - see above"
    exit 1
}
catch {
    Write-Host "---Error---"
    Write-Host $_.Exception.Message

    if ($_.Exception.Response -is [System.Net.HttpWebResponse]) {
        $responseStream = $_.Exception.Response.GetResponseStream()
        if ($null -ne $responseStream) {
            $reader = New-Object System.IO.StreamReader($responseStream)
            try {
                $responseBody = $reader.ReadToEnd()
                Write-Host "Response Body: $responseBody"
            }
            finally {
                $reader.Dispose()
            }
        }
    }
    else {

        try {
             $details = $_.ErrorDetails.ToString() | ConvertFrom-Json
             $details | Format-List
        }
        catch {
             Write-Host "Could not parse ErrorDetails as JSON."
        }

    }

    exit 1
}