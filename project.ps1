# Deployment script for AppRolla framework
#
# Visit this site to learn about its features and see more examples:
# https://github.com/AppVeyor/AppRolla

# Staging environment
New-Environment Staging
# Add-EnvironmentServer Staging "staging-server"

New-Environment Production
# Add-EnvironmentServer Production "web.myserver.com" -DeploymentGroup web
# Add-EnvironmentServer Production "app.myserver.com" -DeploymentGroup app

# Azure environments
# New-AzureEnvironment Azure-Staging -CloudService <cloud-service-name> -Slot <Staging|Production>

<#

# What else could be done in this script?


# Customize web site details for web application deployment:

Set-WebsiteRole $projectName <web-app-artifact-name> `
    -BasePath <website-root-path>                      # for example, c:\websites\mywebsite
    -WebsiteName "My Website" `
    -WebsiteProtocol <http|https> `
    -WebsiteIP <ip> `
    -WebsitePort <port> `
    -WebsiteHost <your-domain> `



# Customize Windows service details:

Set-ServiceRole $projectName <service-artifact-name> `
    -BasePath <service-root-path>                      # e.g. c:\program files\myapp\myservice
    -ServiceExecutable <exe-filename> `                # if service bin folder contains more that one .exe
    -ServiceName <service-name> `
    -ServiceDisplayName <display-name> `
    -ServiceDescription <description> `



# Define your custom deployment tasks here, for example:

Set-DeploymentTask mytask -Before deploy {
    # do something here on remote server before deployment
}

#>