Param (
    $configurationName,
    $variables = @{},
    $artifacts = @{},
    $projectName,
    $projectVersion
)

$scriptsPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# configure deployment
. (Join-Path $scriptsPath "configure.ps1") $configurationName

# perform deployment
$environment = $variables.Environment
if($environment)
{
    Write-Host "Deploying to environment: $environment"

    # does specified environment exist?
    Get-Environment -Name $environment | Out-Null

    # deploy AppRolla application
    New-Deployment $projectName $projectVersion -To $environment
}

# perform Azure deployment
$azureEnvironment = $variables.AzureEnvironment
if($azureEnvironment)
{
    Write-Host "Deploying to Azure CS environment: $azureEnvironment"

    # does specified environment exist?
    Get-Environment -Name $azureEnvironment | Out-Null

    # deploy first Azure application to the selected environment
    foreach($app in Get-Application)
    {
        if($app.Type -eq "Azure")
        {
            New-Deployment $app.Name $projectVersion -To $azureEnvironment
            break
        }
    }
}