$modules = "$home\Documents\WindowsPowerShell\Modules"
Write-Host "Installing modules into your user profile: $modules"

Write-Host "Installing AppRolla module"
New-Item "$modules\AppRolla" -ItemType Directory -Force | Out-Null
(New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/AppRolla/master/AppRolla.psm1", "$modules\AppRolla\AppRolla.psm1")

Write-Host "Installing AppVeyor module"
New-Item "$modules\AppVeyor" -ItemType Directory -Force | Out-Null
(New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/AppVeyor-PowerShell/master/AppVeyor.psm1", "$modules\AppVeyor\AppVeyor.psm1")

$path = Resolve-Path .\
Write-Host "Downloading deployment scripts to the current directory: $path"
(New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/Deployment/master/config.ps1", "$path\config.ps1")
(New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/Deployment/master/deploy.ps1", "$path\deploy.ps1")

if(-not (Test-Path "$path\environments.ps1"))
{
    (New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/Deployment/master/environments.ps1", "$path\environments.ps1")
}

# add registry settings
$settingsPath = "HKCU:\SOFTWARE\AppVeyor\Deployment"
if(-not (Test-Path $settingsPath))
{
    New-Item -Path $settingsPath –Force | Out-Null
    New-ItemProperty -Path $settingsPath -Name ApiAccessKey -Value "" | Out-Null
    New-ItemProperty -Path $settingsPath -Name ApiSecretKey -Value "" | Out-Null
    New-ItemProperty -Path $settingsPath -Name Project -Value "" | Out-Null
    New-ItemProperty -Path $settingsPath -Name Version -Value "" | Out-Null
    New-ItemProperty -Path $settingsPath -Name ServerUsername -Value "administrator" | Out-Null
    New-ItemProperty -Path $settingsPath -Name ServerPassword -Value "" | Out-Null
}