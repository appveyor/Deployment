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
Import-Module "$scriptsFolder\appveyor-deploy-azure.psm1"

<#

Input parameters:
    deployProjectName - the name of AppVeyor project to deploy
    deployArtifactName - Azure Cloud Services artifact name
    subscriptionIdSecure - Subscription ID from .publishsettings file
    subscriptionCertificateSecure - ManagementCertificate value from .publishsettings file
    storageAccountName - Azure storage account name where .cspkg file is stored
    storageAccountKeySecure - Azure storage account key
    serviceName - Azure Cloud Service we are deploying into
    serviceEnvironment - Azure CS environment to deploy: Staging or Production
    upgradeDeployment - if $true - we will upgrade service deployment; otherwise re-create it
#>

$deployProjectName = $parameters["deployProjectName"]
$deployArtifactName = $parameters["deployArtifactName"]
$appveyorApiAccessKey = $parameters["appveyorApiAccessKey"]
$appveyorApiSecretKey = $parameters["appveyorApiSecretKeySecure"]

$subscriptionId = $parameters["subscriptionIdSecure"]
$subscriptionCertificate = $parameters["subscriptionCertificateSecure"]
$storageAccountName = $parameters["storageAccountName"]
$storageAccountKey = $parameters["storageAccountKeySecure"]
$serviceName = $parameters["serviceName"]
$slot = "Staging"
if($parameters["serviceEnvironment"] -ne $null)
{
    $slot = $parameters["serviceEnvironment"]
}
$upgradeDeployment = $true
if($parameters["upgradeDeployment"] -ne $null)
{
    $upgradeDeployment = $parameters["upgradeDeployment"]
}
$deploymentLabel = $projectVersion


# azure package URL and path to .cscfg file
$packageUrl = $null
$cloudConfigUrl = $null
$cloudConfigPath = $null

# START
# =====
function Write-Log($message)
{
    Write-Output "$(Get-Date -f g) - $message"
}

Write-Log "Deploying $projectName $projectVersion"

if($deployProjectName)
{
    Write-Log "Get the last '$deployProjectName' version"

    # set API connection details
    Set-AppveyorConnection $appveyorApiAccessKey $appveyorApiSecretKey

    # we are going to deploy artifacts from another project
    # get project details using Appveyor API
    $deployProject = Get-AppveyorProject -Name $deployProjectName
    Write-Log "Deploying Azure Cloud Service from project '$deployProjectName' version $($deployProject.lastVersion.version)"

    # check project status
    if($deployProject.lastVersion.status -ne "complete")
    {
        throw "Project $deployProjectName version $($deployProject.lastVersion.version) with '$($deployProject.lastVersion.status)' status cannot be deployed."
    }

    # scan artifacts
    foreach($artifact in $deployProject.lastVersion.artifacts)
    {
        if(($deployArtifactName -eq $null -and $artifact.type -eq "AzureCloudService") `
            -or ($deployArtifactName -ne $null -and $artifact.name  -eq "$deployArtifactName"))
        {
            $packageUrl = $artifact.customUrl
        }
        elseif(($deployArtifactName -eq $null -and $artifact.type -eq "AzureCloudServiceConfig") `
            -or ($deployArtifactName -ne $null -and $artifact.name  -eq "$deployArtifactName-config"))
        {
            $cloudConfigUrl = $artifact.customUrl
        }
    }

    # change deployment label
    $deploymentLabel = $deployProject.lastVersion.version
}
else
{
    # it's "deployment" stage of the same project
    # look in artifacts
    foreach($artifact in $artifacts.Values)
    {
        if(($deployArtifactName -eq $null -and $artifact.type -eq "AzureCloudService") `
            -or ($deployArtifactName -ne $null -and $artifact.name  -eq "$deployArtifactName"))
        {
            $packageUrl = $artifact.customUrl
        }
        elseif(($deployArtifactName -eq $null -and $artifact.type -eq "AzureCloudServiceConfig") `
            -or ($deployArtifactName -ne $null -and $artifact.name  -eq "$deployArtifactName-config"))
        {
            $cloudConfigPath = $artifact.path
        }
    }
}

# deploy
New-AzureCloudServiceDeployment `
    -subscriptionId $subscriptionId `
    -subscriptionCertificate $subscriptionCertificate `
    -storageAccountName $storageAccountName `
    -storageAccountKey $storageAccountKey `
    -serviceName $serviceName `
    -slot $slot `
    -upgradeDeployment $upgradeDeployment `
    -deploymentLabel $deploymentLabel `
    -packageUrl $packageUrl `
    -cloudConfigUrl $cloudConfigUrl `
    -cloudConfigPath $cloudConfigPath `
    -cloudConfigVariables $parameters `
    -tempFolder $tempFolder