function New-WindowsServiceDeployment
{
    param
    (
        $serverAddress,
        $serverUsername,
        $serverPassword,
        $serverManagementPort = 5986,
        $serviceName,
        $serviceDisplayName,
        $serviceDescription,
        $appConfigVariables,
        $servicePackageUrl,
        $appveyorApiAccessKey,
        $appveyorApiSecretKey
    )

    # script block to call on remote machine
    # --------------------------------------
    $remoteScript = {
        param
        (
            $serviceName,
            $serviceDisplayName,
            $serviceDescription,
            $appConfigVariables,
            $servicePackageUrl,
            $appveyorApiAccessKey,
            $appveyorApiSecretKey
        )

        # constants
        $APPLICATIONS_FOLDER = "applications"

        function Write-Log($message)
        {
            Write-Output "[$($env:COMPUTERNAME)] $(Get-Date -f g) - $message"
        }

        function Get-AppveyorAuthorizationHeader
        {
            param (
                [string]$apiAccessKey,
                [string]$apiSecretKey,
                [int]$accountId
            )

            $timestamp = [DateTime]::UtcNow.ToString("r")

            # generate signature
            $stringToSign = $timestamp
	        $secretKeyBytes = [byte[]]([System.Text.Encoding]::ASCII.GetBytes($apiSecretKey))
	        $stringToSignBytes = [byte[]]([System.Text.Encoding]::ASCII.GetBytes($stringToSign))
	
	        [System.Security.Cryptography.HMACSHA1] $signer = New-Object System.Security.Cryptography.HMACSHA1(,$secretKeyBytes)
	        $signatureHash = $signer.ComputeHash($stringToSignBytes)
	        $signature = [System.Convert]::ToBase64String($signatureHash)

            $headerValue = "HMAC-SHA1 accessKey=`"$apiAccessKey`", timestamp=`"$timestamp`", signature=`"$signature`""
            if($accountId)
            {
                $headerValue = $headerValue + ", accountId=`"$accountId`""
            }
            return $headerValue
        }

        function Update-ApplicationConfig
        {
            param (
                $configPath,
                $variables
            )

            [xml]$xml = New-Object XML
            $xml.Load($configPath)

            # appSettings section
            foreach($appSettings in $xml.selectnodes("//*[local-name() = 'appSettings']"))
            {
                foreach($setting in $appSettings.ChildNodes)
                {
                    if($setting.key)
                    {
                        $value = $variables[$setting.key]
                        if($value -ne $null)
                        {
                            Write-Log "Updating <appSettings> entry `"$($setting.key)`" to `"$value`""
                            $setting.value = $value
                        }
                    }
                }
            }

            # connectionStrings
            foreach($connectionStrings in $xml.selectnodes("//*[local-name() = 'connectionStrings']"))
            {
                foreach($entry in $connectionStrings.ChildNodes)
                {
                    if($entry.name)
                    {
                        $connectionString = $variables[$entry.name]
                        if($connectionString -ne $null)
                        {
                            Write-Log "Updating <connectionStrings> entry `"$($entry.name)`" to `"$connectionString`""
                            $entry.connectionString = $connectionString
                        }
                    }
                }
            }

            $xml.Save($configPath)
        }

        Write-Log "Start deploying Windows service $serviceName"

        Write-Log "Config variables: $($appConfigVariables.count)"

        # system folders
        $tempPath = [System.IO.Path]::GetTempPath()
        $programFilesFolder = "${Env:ProgramFiles}"
        $systemDrive = [System.IO.Path]::GetPathRoot($programFilesFolder)

        # application folders
        $applicationPath = [System.IO.Path]::Combine($systemDrive, $APPLICATIONS_FOLDER, $serviceName)

        # check if the service is already installed
        $serviceExists = $false
        $existingService = Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'"
        if ($existingService -ne $null)
        {
            Write-Log "Service already exists, stopping..."
            $serviceExists = $true
            $applicationPath = [System.IO.Path]::GetDirectoryName($existingService.PathName)

            # stop the service
            Stop-Service -Name $serviceName -Force

	        # wait 2 sec before continue
	        Start-Sleep -s 2
        }
        else
        {
            Write-Log "Service does not exists. Creating application folder."
            $item = New-Item -ItemType Directory -Force -Path $applicationPath
        }

        # application folder
        Write-Log "Application root folder: $applicationPath"

        # download artifact to temp location
        $artifactPath = [System.IO.Path]::Combine($tempPath, [System.IO.Path]::GetFileNameWithoutExtension([System.IO.Path]::GetRandomFileName()) + ".zip")
        $webClient = New-Object System.Net.WebClient
        if($appveyorApiAccessKey -ne $null)
        {
            $webClient.Headers.Add("Authorization", (Get-AppveyorAuthorizationHeader $appveyorApiAccessKey $appveyorApiSecretKey))
        }
        $webClient.DownloadFile($servicePackageUrl, $artifactPath)
        Write-Log "Package downloaded to $artifactPath"

        # unzip artifact to application folder
        Write-Log "Unzip package to $applicationPath"
        $shellApp = New-Object -com Shell.Application
        $zipFile = $shellApp.Namespace($artifactPath)
        $unzipFolder = $shellApp.Namespace($applicationPath)
        $unzipFolder.CopyHere($zipFile.Items(), 16)

        # find windows service executable
        $serviceExePath = Get-ChildItem $applicationPath\*.exe | Select-Object -First 1
        Write-Log "Service executable: $serviceExePath"

        # update app.config variables
        $appConfigPath = "$serviceExePath.config"
        if(Test-Path $appConfigPath)
        {
            Write-Log "Updating service configuration in $appConfigPath"
            Update-ApplicationConfig -configPath $appConfigPath -variables $appConfigVariables
        }

        # install service if required
        if(-not $serviceExists)
        {
            # install
            if(-not $serviceDisplayName)
            {
                $serviceDisplayName = $serviceName
            }
            if(-not $serviceDescription)
            {
                $serviceDescription = "Windows service deployed by AppVeyor CI."
            }
            New-Service -Name $serviceName -BinaryPathName $serviceExePath `
                -DisplayName $serviceDisplayName -StartupType Automatic -Description $serviceDescription
        }

        # start the service
        Write-Log "Starting service..."
        Start-Service -Name $serviceName

        # cleanup
        Remove-Item $artifactPath -Force
    }
    # --------------------------------------

    # execute remote script
    $securePassword = ConvertTo-SecureString $serverPassword -AsPlainText -Force
    $serverCredential = New-Object System.Management.Automation.PSCredential $serverUsername, $securePassword
    Invoke-Command -ScriptBlock $remoteScript -ComputerName $serverAddress -Port $serverManagementPort -Credential $serverCredential `
        -UseSSL -SessionOption (New-PSSessionOption -SkipCACheck -SkipCNCheck) `
        -ArgumentList $serviceName,$serviceDisplayName,$serviceDescription,$appConfigVariables,$servicePackageUrl,$appveyorApiAccessKey,$appveyorApiSecretKey
}