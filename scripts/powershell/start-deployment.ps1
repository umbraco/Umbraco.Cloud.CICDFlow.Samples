param(
    [Parameter(Position=0)]
    [string] 
    $BaseUrl,
    
    [Parameter(Position=1)]
    [string] 
    $ProjectId,
    
    [Parameter(Position=2)]
    [string] 
    $DeploymentId,
    
    [Parameter(Position=3)]
    [string] 
    $ApiKey
)

$headers = @{
    'Umbraco-Cloud-Api-Key' = $ApiKey
    'Content-Type' = 'application/json'
}

$body = @{
    'deploymentState' = 'Queued'
} | ConvertTo-Json

$url = "$BaseUrl/v1/projects/$ProjectId/deployments/$DeploymentId"


try {
    Write-Host "Requesting start Deployment at $url"
    $response = Invoke-RestMethod -URI $url -Headers $headers -Method PATCH -Body $body
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