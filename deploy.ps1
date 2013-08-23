Param (
    $variables = @{},
    $artifacts = @{},
    $scriptFolder,
    $projectName,
    $projectVersion
)

# configure deployment
. (Join-Path $scriptFolder "configure.ps1")

# perform deployment
$environment = $variables.Environment
if($environment)
{
    # does specified environment exist?
    Get-Environment -Name $environment

    # deploy AppRolla application
    New-Deployment $projectName $projectVersion -To $environment

    # deploy first Azure application to the selected environment
    foreach($app in Get-Application)
    {
        if($app.Type -eq "Azure")
        {
            New-Deployment $app.Name $projectVersion -To $environment
        }
    }
}