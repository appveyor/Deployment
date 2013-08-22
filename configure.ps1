# import modules
Import-Module AppRolla
Import-Module AppVeyor

# globals
$scriptsPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$settingsPath = "HKCU:SOFTWARE\AppVeyor\Deployment"

try
{
    # is it AppVeyor CI environment?
    if(-not $projectName)
    {
        # no, the script is being run interactively from command line
    
        # load script parameters from the Registry
        if(-not (Test-Path $settingsPath))
        {
            throw "Cannot read script parameters from Registry key: $settingsPath"
        }

        $variables = Get-ItemProperty -Path $settingsPath
    }

    # get script settings
    $specificProject = $false
    if($variables.Project)
    {
        $specificProject = $true
        $projectName = $variables.Project
        $projectVersion = $variables.Version
    }
    $apiAccessKey = $variables.ApiAccessKey
    $apiSecretKey = $variables.ApiSecretKey
    $serverUsername = $variables.ServerUsername
    $serverPassword = $variables.ServerPassword

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

            # get project artifacts
            $projectArtifacts = $version.artifacts
        }
        else
        {
            # load last project version
            $project = Get-AppveyorProject -Name $projectName

            # get project artifacts
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

    # load project specific settings and customizations
    . (Join-Path $scriptsPath "project.ps1")

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