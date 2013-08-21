# Staging environment
New-Environment Staging
# Add-EnvironmentServer Staging "staging-server"

New-Environment Production
# Add-EnvironmentServer Production "web.myserver.com" -DeploymentGroup web
# Add-EnvironmentServer Production "app.myserver.com" -DeploymentGroup app

# custom deployment tasks go here
# Set-DeploymentTask mytask -Before deploy {
#
#    # do something here on remote server before deployment
#
# }