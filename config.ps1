# import modules
Import-Module AppRolla
Import-Module AppVeyor

# globals
$scriptsPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$settingsPath = "HKCU:SOFTWARE\AppVeyor\Deployment"

$apiAccessKey = $null
$apiSecretKey = $null
$specificProject = $true
$serverUsername = $null
$serverPassword = $null

try
{
    # is it AppVeyor CI environment?
    if($projectName)
    {
        # yes, this is AppVeyor CI environment

        # are we deploying specific project?
        if(-not $variables -or $variables["Project"] -eq $null)
        {
            # no, note that
            $specificProject = $false
        }
        else
        {
            # get script settings
            $projectName = $variables["Project"]
            $projectVersion = $variables["Version"]
            $apiAccessKey = $variables["ApiAccessKey"]
            $apiSecretKey = $variables["ApiSecretKey"]
            $serverUsername = $variables["ServerUsername"]
            $serverPassword = $variables["ServerPassword"]
        }
    }
    else
    {
        # script is being run interactively from command line
    
        # load script parameters from the Registry
        if(-not (Test-Path $settingsPath))
        {
            throw "Cannot read script parameters from Registry key: $settingsPath"
        }

        $scriptData = Get-ItemProperty -Path $settingsPath

        # get script settings
        $projectName = $scriptData.Project
        $projectVersion = $scriptData.Version
        $apiAccessKey = $scriptData.ApiAccessKey
        $apiSecretKey = $scriptData.ApiSecretKey
        $serverUsername = $scriptData.ServerUsername
        $serverPassword = $scriptData.ServerPassword
    }

    if(-not $apiAccessKey -or -not $apiSecretKey)
    {
        throw "Specify ApiAccessKey and ApiSecretKey variables"
    }

    # set API keys
    Set-AppveyorConnection $apiAccessKey $apiSecretKey

    # this is needed to download artifacts on remote servers
    Set-DeploymentConfiguration AppveyorApiKey $apiAccessKey
    Set-DeploymentConfiguration AppveyorApiSecret $apiSecretKey

    # add new application
    New-Application $projectName

    # add application roles from artifacts
    $projectArtifacts = $null
    if($specificProject)
    {
        if($projectVersion)
        {
            # load specific project version
            $version = Get-AppveyorProjectVersion $projectName $projectVersion

            # get project artifacts from the last version
            $projectArtifacts = $version.artifacts
        }
        else
        {
            # load project details
            $project = Get-AppveyorProject -Name $projectName

            # get project artifacts from the last version
            $projectArtifacts = $project.lastVersion.artifacts
        }
    }
    else
    {
        $projectArtifacts = $artifacts.values
    }

    # build AppRolla application from artifacts
    foreach($artifact in $projectArtifacts)
    {
        if($artifact.type -eq "WindowsApplication")
        {
            # Windows service or console application
            Add-ServiceRole $projectName $artifact.name -PackageUrl $artifact.url -DeploymentGroup app
        }
        elseif($artifact.type -eq "WebApplication")
        {
            # Web application
            Add-WebsiteRole $projectName $artifact.name -PackageUrl $artifact.url -DeploymentGroup web
        }
    }

    # load environments and other customizations
    . (Join-Path $scriptsPath "environments.ps1")

    # set environment credentials
    if($serverUsername -and $serverPassword)
    {
        $securePassword = ConvertTo-SecureString $serverPassword -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential $serverUsername, $securePassword

        foreach($environment in (Get-Environment))
        {
            if($environment.Name -ne "local")
            {
                Set-Environment $environment.Name -Credential $credential
            }
        }
    }
}
catch
{
    Remove-Module AppVeyor
    Remove-Module AppRolla
    throw
}