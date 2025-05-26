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
    $FilePath,

    [Parameter(Position=4)]    
    [string] 
    $BaseUrl = "https://api.cloud.umbraco.com"
)

### Endpoint docs
# https://docs.umbraco.com/umbraco-cloud/set-up/project-settings/umbraco-cicd/umbracocloudapi#upload-zip-source-file
#
$url = "$BaseUrl/v1/projects/$ProjectId/deployments/$DeploymentId/package"

$fieldName = 'file'
$contentType = 'application/zip'
$umbracoHeader = @{ 'Umbraco-Cloud-Api-Key' = $ApiKey }


$fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open)
$fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new('form-data')
$fileHeader.Name = $fieldName
$fileHeader.FileName = Split-Path -leaf $filePath
$fileContent = [System.Net.Http.StreamContent]::new($fileStream)
$fileContent.Headers.ContentDisposition = $fileHeader
$fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($contentType)

$multipartContent = [System.Net.Http.MultipartFormDataContent]::new()
$multipartContent.Add($fileContent)

try {
    $response = Invoke-WebRequest -Body $multipartContent -Headers $umbracoHeader  -Method 'POST' -Uri $url
    if ($response.StatusCode -ne 202)
    {
        Write-Host "---Response Start---"
        Write-Host $response
        Write-Host "---Response End---"
        Write-Host "Unexpected response - see above"
        exit 1
    }

    Write-Host $response.Content | ConvertTo-Json
    exit 0
}
catch 
{
    Write-Host "---Error---"
    Write-Host $_
    exit 1
}