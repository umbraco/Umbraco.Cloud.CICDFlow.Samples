param(    
    [Parameter(Position=0)]
    [string] 
    $ProjectId,
    
    [Parameter(Position=1)]
    [string] 
    $ApiKey,
    
    [Parameter(Position=2)]
    [string] 
    $FilePath,

    [Parameter(Position=3)]    
    [string] 
    $Description = $null,

    [Parameter(Position=4)]    
    [string] 
    $Version = $null,

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
$url = "$BaseUrl/v2/projects/$ProjectId/deployments/artifacts"

# test if file is present
if (-not $FilePath) {
    Write-Host "FilePath is empty"
    exit 1
}

if (-not (Test-Path -Path $FilePath -PathType Leaf)) {
    Write-Host "FilePath does not contain a file"
    exit 1
}
# end test

$Headers = @{
    'accept' = 'application/json'
    'Content-Type' = 'multipart/form-data'
    'Umbraco-Cloud-Api-Key' = $ApiKey
}
$contentType = 'application/zip'

$multipartContent = [System.Net.Http.MultipartFormDataContent]::new()

$fileStream = [System.IO.FileStream]::new($filePath, [System.IO.FileMode]::Open)
$fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new('form-data')
$fileHeader.Name = 'file'
$fileHeader.FileName = Split-Path -leaf $filePath
$fileContent = [System.Net.Http.StreamContent]::new($fileStream)
$fileContent.Headers.ContentDisposition = $fileHeader
$fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($contentType)

$multipartContent.Add($fileContent)

$stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
$stringHeader.Name = "description"
$StringContent = [System.Net.Http.StringContent]::new($Description)
$StringContent.Headers.ContentDisposition = $stringHeader
$multipartContent.Add($stringContent)

$stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
$stringHeader.Name = "version"
$StringContent = [System.Net.Http.StringContent]::new($Version)
$StringContent.Headers.ContentDisposition = $stringHeader
$multipartContent.Add($stringContent)


try {
    $response = Invoke-WebRequest -Body $multipartContent -Headers $Headers  -Method 'POST' -Uri $url
    if ($response.StatusCode -ne 200)
    {
        Write-Host "---Response Start---"
        Write-Host $response
        Write-Host "---Response End---"
        Write-Host "Unexpected response - see above"
        exit 1
    }

    $responseJson = $response.Content | ConvertFrom-Json
    $artifactId = $responseJson.artifactId

    switch ($PipelineVendor) {
        "GITHUB" {
            "artifactId=$($artifactId)" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        }
        "AZUREDEVOPS" {
            Write-Host "##vso[task.setvariable variable=artifactId;isOutput=true]$($artifactId)"
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

    Write-Host "Artifact uploaded - Artifact Id: $($artifactId)"
    Write-Host "--- Upload Response ---"
    Write-Output $responseJson

    exit 0
}
catch 
{
    Write-Host "---Error---"
    Write-Host $_.Exception.Message
    if ($null -ne $_.Exception.Response) {
        $responseStream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response Body: $responseBody"
    }
    exit 1
}