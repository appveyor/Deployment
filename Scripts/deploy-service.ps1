Param (
    $parameters = @{},	
    $artifacts = @{},
    $scriptPath,
    $buildFolder,
    $srcFolder,
    $outFolder,
    $tempFolder,
    $projectName,
    $projectVersion,
    $projectBuildNumber
)

$ErrorActionPreference = "stop"

# import required modules
$scriptsFolder = [System.IO.Path]::GetDirectoryName($scriptPath)
Import-Module "$scriptsFolder\appveyor-api.psm1"
Import-Module "$scriptsFolder\appveyor-deploy-service.psm1"

# get input parameters
$appveyorApiAccessKey = $parameters["appveyorApiAccessKey"]
$appveyorApiSecretKey = $parameters["appveyorApiSecretKeySecure"]
$serverAddresses = $parameters["serverAddressesSecure"]
$serverManagementPort = $parameters["serverManagementPortSecure"]
$serverUsername = $parameters["serverUsername"]
$serverPassword = $parameters["serverPassword"]

$deployProjectName = $parameters["deployProjectName"]
$deployArtifactName = $parameters["deployArtifactName"]
$servicePackageUrl = $null
$serviceName = $parameters["serviceName"]
$serviceDisplayName = $parameters["serviceDisplayName"]
$serviceDescription = $parameters["serviceDescription"]

function Write-Log($message)
{
    Write-Output "$(Get-Date -f g) - $message"
}

if($deployProjectName)
{
    Write-Log "Get the last '$deployProjectName' version"

    # set API connection details
    Set-AppveyorConnection $appveyorApiAccessKey $appveyorApiSecretKey

    # we are going to deploy artifacts from another project
    # get project details using Appveyor API
    $deployProject = Get-AppveyorProject -Name $deployProjectName
    Write-Log "Deploying artifacts from project '$deployProjectName' version $($deployProject.lastVersion.version)"

    # check project status
    if($deployProject.lastVersion.status -ne "complete")
    {
        throw "Project $deployProjectName version $($deployProject.lastVersion.version) with '$($deployProject.lastVersion.status)' status cannot be deployed."
    }

    # scan artifacts
    foreach($artifact in $deployProject.lastVersion.artifacts)
    {
        if(($deployArtifactName -ne $null -and $artifact.name -eq $deployArtifactName) -or
            ($deployArtifactName -eq $null -and $artifact.type -eq "WindowsApplication"))
        {
            $servicePackageUrl = $artifact.url
            $deployArtifactName = $artifact.name
            break
        }
    }
}
else
{
    # it's "deployment" stage of the same project
    # look in artifacts
    foreach($artifact in $artifacts.values)
    {
        if(($deployArtifactName -ne $null -and $artifact.name -eq $deployArtifactName) -or
            ($deployArtifactName -eq $null -and $artifact.type -eq "WindowsApplication"))
        {
            $servicePackageUrl = $artifact.url
            $deployArtifactName = $artifact.name
            break
        }
    }
}

if($servicePackageUrl -eq $null)
{
    throw "Artifact of type 'WindowsApplication' was not found. Deployment aborted."
}

if($serviceName -eq $null)
{
    $serviceName = $deployArtifactName
}

Write-Log "Windows service name: $serviceName"
Write-Log "Windows service package URL: $servicePackageUrl"

# call installer for each server in the list
foreach($serverAddress in $serverAddresses.split(","))
{
    New-WindowsServiceDeployment `
        -serverAddress $serverAddress.Trim() `
        -serverUsername $serverUsername `
        -serverPassword $serverPassword `
        -serverManagementPort $serverManagementPort `
        -serviceName $serviceName `
        -serviceDisplayName $serviceDisplayName `
        -serviceDescription $serviceDescription `
        -appConfigVariables $parameters `
        -servicePackageUrl $servicePackageUrl `
        -appveyorApiAccessKey $appveyorApiAccessKey `
        -appveyorApiSecretKey $appveyorApiSecretKey
}