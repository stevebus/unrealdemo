$root_path = Split-Path $PSScriptRoot -Parent
Import-Module "$root_path\deployment\PS-Library" -Global



function New-Deployment() {

    #region greetings
    Write-Host
    Write-Host "################################################"
    Write-Host "################################################"
    Write-Host "####                                        ####"
    Write-Host "#### Unreal Engine and Azure Digital Twins  ####"
    Write-Host "####             integration demo           ####"
    Write-Host "####                                        ####"
    Write-Host "################################################"
    Write-Host "################################################"

    Start-Sleep -Milliseconds 1500

    Write-Host
    Write-Host "Welcome to the Unreal Engine and Azure Digital Twins (ADT) integration demo. This deployment script will help you deploy a sandbox environment in your Azure subscription. This demo leverages the ADT Link plugin, that was created along with this sample demo by WSP in collaboration with Microsoft and Epic Games, in order to demonstrate how to integrate Azure Digital Twins with the Unreal Engine."
    Write-Host
    Write-Host "Press Enter to continue."
    Read-Host
    #endregion

    #region validate CLI version
    $cli_valid = Read-CliVersion -min_version "2.28"
    if (!$cli_valid) {
        return $null
    }

    $iot_ext_valid = Read-CliExtensionVersion -min_version "0.11.0" -name 'azure-iot' -auto_update $true
    if (!$iot_ext_valid) {
        return $null
    }
    #endregion

    #region set azure susbcription and resource providers
    Set-AzureAccount

    Write-Host
    Write-Host "Registering ADT resource provider in your subscription"
    az provider register --namespace 'Microsoft.DigitalTwins'
    #endregion

    #region region
    $locations = Get-ResourceProviderLocations -provider 'Microsoft.DigitalTwins' -typeName 'DigitalTwinsInstances' | Sort-Object

    $option = Get-InputSelection `
        -options $locations `
        -text "Choose a region for your deployment from this list (using its Index):"

    $script:location = $locations[$option - 1].Replace(' ', '').ToLower()
    #endregion

    #region resource group
    Set-ProjectName

    Write-Host
    if ($script:create_resource_group) {
        Write-Host "Resource group '$script:resource_group_name' does not exist. Creating now."
        $null = az group create -n $script:resource_group_name --location $script:location
    }
    else {
        Write-Host "Resource group '$script:resource_group_name' already exists in current subscription."
    }
    #endregion

    #region AAD
    Set-EnvironmentHash -hash_length 4

    Write-Host
    Write-Host "Collecting current user information"
    $script:userId = az ad signed-in-user show --query objectId -o tsv

    $script:appRegName = "$($script:resource_group_name)-$($script:env_hash)"
    
    Write-Host
    Write-Host "Creating app registration manifest"
    $manifest = @(
        @{
            "resourceAppId" = "0b07f429-9f4b-4714-9392-cc5e8e80c8b0"
            "resourceAccess" = @(
                @{
                    "id" = "4589bd03-58cb-4e6c-b17f-b580e39652f8"
                    "type" = "Scope"
                }
            )
        }
    )
    Set-Content -Path "manifest.json" -Value (ConvertTo-Json $manifest -Depth 5)

    Write-Host
    Write-Host "Creating app registration '$($script:appRegName)' in Azure Active Directory"
    $script:appReg = az ad app create `
        --display-name $script:appRegName `
        --available-to-other-tenants $false `
        --reply-urls http://localhost `
        --native-app `
        --required-resource-accesses "@manifest.json" | ConvertFrom-Json

    Write-Host
    Write-Host "Creating client secret for app registration '$($script:appRegName)'"
    Start-Sleep -Milliseconds 1500
    $script:appRegSecret = az ad app credential reset --id $script:appReg.appId --append | ConvertFrom-Json
    #endregion

    #region create deployment
    $template = "$($root_path)\deployment\azuredeploy.bicep"
    $parameters = "$($root_path)\deployment\azuredeploy.parameters.json"
    $deployment_id = "$($script:project_name)-$($script:env_hash)"

    $template_parameters = @{
        "projectName"    = @{ "value" = $script:project_name }
        "unique"         = @{ "value" = $script:env_hash }
        "userId"         = @{ "value" = $script:userId }
        "appRegId"       = @{ "value" = $script:appReg.appId }
        "appRegPassword" = @{ "value" = $script:appRegSecret.password }
        "tenantId"       = @{ "value" = $script:appRegSecret.tenant }
        "repoOrgName"    = @{ "value" = "stevebus" }
        "repoBranchName" = @{ "value" = $(git rev-parse --abbrev-ref HEAD) }
    }
    Set-Content -Path $parameters -Value (ConvertTo-Json $template_parameters -Depth 5)

    Write-Host
    Write-Host "Creating resource group deployment with id '$deployment_id'"
    Read-Host ">"

    $script:deployment_output = az deployment group create `
        --resource-group $script:resource_group_name `
        --name $deployment_id `
        --mode Incremental `
        --template-file $template `
        --parameters $parameters | ConvertFrom-Json
    
    if (!$script:deployment_output) {
        throw "Something went wrong with the resource group deployment. Ending script."        
    }

    $important_info = az deployment group show `
        -g $script:resource_group_name `
        -n $deployment_id `
        --query properties.outputs.importantInfo.value
    #endregion

    #region create unreal config file
    Write-Host
    Write-Host "Creating unreal config file"
    Set-Content -Path "$($root_path)/deployment/unreal-plugin-config.json" -Value ($important_info)
    #endregion

    #region mock devices config file
    $script:iot_hub_name = ($important_info | ConvertFrom-Json).iotHubName

    $mock_devices = Get-Content -Path "$($root_path)/devices/mock-devices-template.json" | ConvertFrom-Json
    $iot_hub = az iot hub show -g $script:resource_group_name -n $script:iot_hub_name | ConvertFrom-Json
    $iot_hub_devices = az iot hub device-identity list -g $script:resource_group_name -n $script:iot_hub_name |ConvertFrom-Json

    foreach ($mock_device in $mock_devices) {
        if ($mock_device.configuration._kind -eq "hub") {
            $device = $iot_hub_devices | Where-Object { $_.deviceId -eq $mock_device.configuration.deviceId }

            if (!$device) {
                Write-Host
                Write-Host "Creating mock device $($mock_device.configuration.deviceId) in IoT hub"
                $device = az iot hub device-identity create `
                    -g $script:resource_group_name `
                    -n $script:iot_hub_name `
                    -d $mock_device.configuration.deviceId

                $device_conn_string = "HostName=$($iot_hub.properties.hostName);DeviceId=$($device.deviceId);SharedAccessKey=$($device.authentication.symmetricKey.primaryKey)"
            }
            else {
                $device_conn_string = az iot hub device-identity connection-string show `
                    -g $script:resource_group_name `
                    -n $script:iot_hub_name `
                    -d $device.deviceId `
                    --query connectionString -o tsv
            }

            $mock_device.configuration.connectionString = $device_conn_string
        }
    }

    Set-Content -Path "$($root_path)/devices/mock-devices.json" -Value (ConvertTo-Json $mock_devices -Depth 20)
    #endregion
}

New-Deployment