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
#New-Deployment $projectName $projectVersion -To Staging