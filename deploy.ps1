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

    # deploy
    New-Deployment $projectName $projectVersion -To $environment
}