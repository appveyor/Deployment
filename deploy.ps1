Param (
    $variables = @{},
    $artifacts = @{},
    $scriptFolder,
    $projectName,
    $projectVersion
)

# load configuration
. (Join-Path $scriptFolder "config.ps1")

# perform deployment
#New-Deployment $projectName $projectVersion -To Staging