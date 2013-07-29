$global:appveyorApiUrl = "https://ci.appveyor.com"
$global:appveyorApiAccessKey = $null
$global:appveyorApiSecretKey = $null
$global:appveyorApiAccountId = $null

function Get-AppveyorProject
{
    param (
        [Parameter(Mandatory=$false)]
        [int]$Id,

        [Parameter(Mandatory=$false)]
        [string]$Name
    )

    if($Name)
    {
        # get project by name
        Invoke-ApiGet "/api/projects?name=$Name"
    }
    elseif($Id)
    {
        # get project by ID
        Invoke-ApiGet "/api/projects?id=$Id"
    }
    else
    {
        # return all projects
        Invoke-ApiGet "/api/projects"
    }
}

function Invoke-ApiGet
{
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$resourceUri
    )

    $headers = @{
        "Authorization" = Get-AuthorizationHeaderValue
    }

    $url = Get-ApiResourceUrl -resourceUri $resourceUri
    return Invoke-RestMethod -Uri $url -Headers $headers -Method Get
}

function Get-ApiResourceUrl
{
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$resourceUri
    )

    return $global:appveyorApiUrl.TrimEnd('/') + "/" + $resourceUri.TrimStart("/")
}

function Set-AppveyorConnection
{
    param (
        [Parameter(Position=0, Mandatory=$true)]
        [string]$apiAccessKey,

        [Parameter(Position=1, Mandatory=$true)]
        [string]$apiSecretKey,

        [Parameter(Mandatory=$false)]
        [int]$accountId,

        [Parameter(Mandatory=$false)]
        [string]$apiUrl
    )

    $global:appveyorApiAccessKey = $apiAccessKey
    $global:appveyorApiSecretKey = $apiSecretKey

    if($accountId)
    {
        $global:appveyorApiAccountId = $accountId
    }

    if($apiUrl)
    {
        $global:appveyorApiUrl = $apiUrl
    }
}

function Get-AuthorizationHeaderValue
{
    $apiAccessKey = $global:appveyorApiAccessKey
    $apiSecretKey = $global:appveyorApiSecretKey
    $accountId = $global:appveyorApiAccountId

    if($apiAccessKey -eq $null -or $apiSecretKey -eq $null)
    {
        throw "Call Set-AppveyorConnection <api-access-key> <api-secret-key> to initialize API security context"
    }

    $timestamp = [DateTime]::UtcNow.ToString("r")

    # generate signature
    $stringToSign = $timestamp
	$secretKeyBytes = [byte[]]([System.Text.Encoding]::ASCII.GetBytes($apiSecretKey))
	$stringToSignBytes = [byte[]]([System.Text.Encoding]::ASCII.GetBytes($stringToSign))
	
	[System.Security.Cryptography.HMACSHA1] $signer = New-Object System.Security.Cryptography.HMACSHA1(,$secretKeyBytes)
	$signatureHash = $signer.ComputeHash($stringToSignBytes)
	$signature = [System.Convert]::ToBase64String($signatureHash)

    $headerValue = "HMAC-SHA1 accessKey=`"$apiAccessKey`", timestamp=`"$timestamp`", signature=`"$signature`""
    if($accountId)
    {
        $headerValue = $headerValue + ", accountId=`"$accountId`""
    }
    return $headerValue
}