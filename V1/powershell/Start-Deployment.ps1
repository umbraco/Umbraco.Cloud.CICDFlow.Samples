param(
    [Parameter(Position=0)]
    [string] 
    $ProjectId,
    
    [Parameter(Position=1)]
    [string] 
    $DeploymentId,
    
    [Parameter(Position=2)]
    [string] 
    $ApiKey,

    [Parameter(Position=3)]    
    [string] 
    $BaseUrl = "https://api.cloud.umbraco.com"
)

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#start-deployment
#
$url = "$BaseUrl/v1/projects/$ProjectId/deployments/$DeploymentId"

$headers = @{
    'Umbraco-Cloud-Api-Key' = $ApiKey
    'Content-Type' = 'application/json'
}

$requestBody = @{
    'deploymentState' = 'Queued'
} | ConvertTo-Json

try {
    Write-Host "Requesting start Deployment at $url"
    $response = Invoke-RestMethod -URI $url -Headers $headers -Method PATCH -Body $requestBody
    $status = $response.deploymentState

    if ($status -eq "Queued") {
        Write-Host $Response.updateMessage
        exit 0
    }

    Write-Host "---Response Start---"
    Write-Host $response
    Write-Host "---Response End---"
    Write-Host "Unexpected response - see above"
    exit 1
}
catch {
    Write-Host "---Error---"
    Write-Host $_
    exit 1
}