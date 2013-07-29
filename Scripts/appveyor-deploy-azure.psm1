Import-Module Azure

function New-AzureCloudServiceDeployment
{
    param
    (
        $subscriptionId,
        $subscriptionCertificate,
        $storageAccountName,
        $storageAccountKey,
        $serviceName,
        $slot,
        $upgradeDeployment,
        $deploymentLabel,
        $packageUrl,
        $cloudConfigUrl,
        $cloudConfigPath,
        $cloudConfigVariables,
        $tempFolder
    )

    function Write-Log($message)
    {
        Write-Output "$(Get-Date –f g) - $message"
    }

    function SetupAzureSubscription()
    {
        $subscriptionName = "DeploySubscription"
        $publishSettingsFile = [System.IO.Path]::Combine($tempFolder, "azure-subscription.publishsettings")
        $publishSettingsXml = @"
<?xml version="1.0" encoding="utf-8"?>
<PublishData>
    <PublishProfile
    PublishMethod="AzureServiceManagementAPI"
    Url="https://management.core.windows.net/"
    ManagementCertificate="$subscriptionCertificate">
    <Subscription
        Id="$subscriptionId"
        Name="$subscriptionName" />
    </PublishProfile>
</PublishData>
"@

        # create publish settings file
        Write-Log "Create Azure subscription settings file"
        $sf = New-Item $publishSettingsFile -type file -force -value $publishSettingsXml

        # import subscription
        Write-Log "Import publishing settings profile"
        Import-AzurePublishSettingsFile $publishSettingsFile
        Set-AzureSubscription -CurrentStorageAccount $storageAccountName -SubscriptionName $subscriptionName
        Set-AzureSubscription -DefaultSubscription $subscriptionName
    }

    function UpdateAzureConfig($configPath, $variables)
    {
        [xml]$xml = New-Object XML
        $xml.Load($configPath)

        foreach($configSettings in $xml.selectnodes("//*[local-name() = 'ConfigurationSettings']"))
        {
            foreach($setting in $configSettings.ChildNodes)
            {
                $value = $variables[$setting.name]
                if($value -ne $null)
                {
                    Write-Log "Updating <ConfigurationSettings> entry `"$($setting.name)`" to `"$value`""
                    $setting.value = $value
                }
            }
        }
        $xml.Save($configPath)
    }

    function CreateDeployment()
    {
        Write-Log "Creating new $slot deployment in $serviceName"

        # create and wait
        $deployment = New-AzureDeployment -Slot $slot -Package $packageUrl -Configuration $cloudConfigPath -label $deploymentLabel -ServiceName $serviceName
        WaitForAllInstancesRunning

        # get URL
        $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
        $deploymentUrl = $deployment.url

        Write-Log "Deployment created, URL: $deploymentUrl"
    }

    function UpgradeDeployment()
    {
        Write-Log "Upgrading $slot deployment in $serviceName"

        $deployment = Set-AzureDeployment -Upgrade -Slot $slot -Package $packageUrl -Configuration $cloudConfigPath -label $deploymentLabel -ServiceName $serviceName -Force
        WaitForAllInstancesRunning

        # get URL
        $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
        $deploymentUrl = $deployment.url

        Write-Log "Deployment upgraded, URL: $deploymentUrl"
    }

    function DeleteDeployment()
    {
        Write-Log "Deleting $slot deployment in $serviceName"

        $deployment = Remove-AzureDeployment -Slot $slot -ServiceName $serviceName -Force

        Write-Log "Deployment deleted"
    }

    function WaitForAllInstancesRunning()
    {
        $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot
        $instanceStatuses = @("") * $deployment.RoleInstanceList.Count
        do
        {
            $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot

            for($i = 0; $i -lt $deployment.RoleInstanceList.Count; $i++)
            {
                $instanceName = $deployment.RoleInstanceList[$i].InstanceName
                $instanceStatus = $deployment.RoleInstanceList[$i].InstanceStatus
                if ($instanceStatuses[$i] -ne $instanceStatus)
                {
                    $instanceStatuses[$i] = $instanceStatus
                    Write-Log "Starting Instance '$instanceName': $instanceStatus"
                }
            }
        }
        until(AllInstancesRunning($deployment.RoleInstanceList))
    }

    function AllInstancesRunning($roleInstanceList)
    {
        foreach ($roleInstance in $roleInstanceList)
        {
            if ($roleInstance.InstanceStatus -ne "ReadyRole")
            {
                return $false
            }
        }

        return $true
    }

    function Deploy()
    {
        Write-Log "Check if $slot deployment already exists"

        $deployment = Get-AzureDeployment -ServiceName $serviceName -Slot $slot -ErrorAction silentlycontinue
        if ($deployment.Name -ne $null)
        {
            Write-Log "$slot deployment exists"

            # should we delete or upgrade existing deployment?
            if($upgradeDeployment)
            {
                UpgradeDeployment
            }
            else
            {
                Write-Log "Upgrade is not enabled. Re-creating $slot deployment."

                DeleteDeployment
                CreateDeployment
            }
        }
        else
        {
            Write-Log "$slot deployment does not exist"

            CreateDeployment
        }
    }

    # setup subscription
    if($subscriptionId -ne $null)
    {
        SetupAzureSubscription
    }

    $blobHost = ".blob.core.windows.net/"
    if($packageUrl -eq $null -or $packageUrl.indexOf($blobHost) -eq -1)
    {
        throw "Please configure custom Azure Blob storage to store project artifacts"
    }

    Write-Log "Package URL: $packageUrl"

    # download .cscfg file
    if($cloudConfigUrl -ne $null)
    {
        $cloudConfigPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName())
        Write-Log "Downloading .cscfg from $cloudConfigUrl to $cloudConfigPath"

        # parse URL
        $hostIdx = $cloudConfigUrl.indexOf($blobHost)
        $relativeUrl = $cloudConfigUrl.substring($hostIdx + $blobHost.length)

        # get container and blob name
        $idx = $relativeUrl.indexOf("/")
        $containerName = $relativeUrl.substring(0, $idx)
        $blobName = $relativeUrl.substring($idx + 1)

        # download config from blob
        $blobContext = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
        $result = Get-AzureStorageBlobContent -Container $containerName -Blob $blobName -Destination $cloudConfigPath -Context $blobContext
    }

    # update .cscfg file
    if($cloudConfigVariables -ne $null)
    {
        UpdateAzureConfig $cloudConfigPath $cloudConfigVariables
    }

    # start deployment!
    Deploy

    # cleanup
    if((Test-Path $cloudConfigPath) -and $cloudConfigUrl -ne $null)
    {
        Remove-Item $cloudConfigPath -Force
    }
}