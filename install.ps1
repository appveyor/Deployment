Write-Host "Installing AppRolla and AppVeyor modules into your user profile"
$modules = "$home\Documents\WindowsPowerShell\Modules"

Write-Host "Installing AppRolla module"
New-Item "$modules\AppRolla" -ItemType Directory -Force | Out-Null
(New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/AppRolla/master/AppRolla.psm1", "$modules\AppRolla\AppRolla.psm1")

Write-Host "Installing AppVeyor module"
New-Item "$modules\AppVeyor" -ItemType Directory -Force | Out-Null
(New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/AppVeyor-PowerShell/master/AppVeyor.psm1", "$modules\AppVeyor\AppVeyor.psm1")

Write-Host "Downloading deployment scripts to the current directory"
$path = Resolve-Path .\
(New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/Deployment/master/config.ps1", "$path\config.ps1")
(New-Object Net.WebClient).DownloadFile("https://raw.github.com/AppVeyor/Deployment/master/deploy.ps1", "$path\deploy.ps1")