# import modules
Import-Module AppRolla
Import-Module AppVeyor

# scripts folder
$scriptsPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

# load environments and taks
. (Join-Path $scriptsPath "environments.ps1")

# load project details and configure AppRolla application
# if script being run interactively
# otherwise application will be configured in deploy.ps1
if(-not $env:AppVeyor)
{
    # load script parameters from the Registry
    $scriptData = Get-ItemProperty -Path "HKCU:SOFTWARE\AppVeyor\Deployment"

    # load project details

    # add application
}