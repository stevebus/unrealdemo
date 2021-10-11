function New-Password {
    param(
        [int] $length = 15
    )

    $punc = 46..46
    $digits = 48..57
    $lcLetters = 65..90
    $ucLetters = 97..122
    $password = `
        [char](Get-Random -Count 1 -InputObject ($lcLetters)) + `
        [char](Get-Random -Count 1 -InputObject ($ucLetters)) + `
        [char](Get-Random -Count 1 -InputObject ($digits)) + `
        [char](Get-Random -Count 1 -InputObject ($punc))
    $password += get-random -Count ($length - 4) `
        -InputObject ($punc + $digits + $lcLetters + $ucLetters) |`
        ForEach-Object -begin { $aa = $null } -process { $aa += [char] $_ } -end { $aa }

    return $password
}

function Get-EnvironmentHash {
    param(
        [int] $hash_length = 8
    )
    $env_hash = (New-Guid).Guid.Replace('-', '').Substring(0, $hash_length).ToLower()

    return $env_hash
}

function Get-ResourceProviderLocations {
    param(
        [string] $provider,
        [string] $typeName
    )

    $providers = $(az provider show --namespace $provider | ConvertFrom-Json)
    $resourceType = $providers.ResourceTypes | Where-Object { $_.ResourceType -eq $typeName } | Sort-Object -Property locations

    return $resourceType.locations
}

function Set-EnvironmentHash {
    param(
        [int] $hash_length = 4
    )
    $script:env_hash = Get-EnvironmentHash -hash_length $hash_length
}

function Read-CliVersion {
    param (
        [version]$min_version = "2.21"
    )

    $az_version = az version | ConvertFrom-Json
    [version]$cli_version = $az_version.'azure-cli'

    Write-Host
    Write-Host "Verifying your Azure CLI installation version..."
    Start-Sleep -Milliseconds 500

    if ($min_version -gt $cli_version) {
        Write-Host
        Write-Host "You are currently using the Azure CLI version $($cli_version) and this wizard requires version $($min_version) or later. You can update your CLI installation with 'az upgrade' and come back at a later time."

        return $false
    }
    else {
        Write-Host
        Write-Host "Great! You are using a supported Azure CLI version."

        return $true
    }
}

function Set-AzureAccount {
    param()

    Write-Host
    Write-Host "Retrieving your current Azure subscription..."
    Start-Sleep -Milliseconds 500

    $account = az account show | ConvertFrom-Json

    $option = Get-InputSelection `
        -options @("Yes", "No. I want to use a different subscription") `
        -text "You are currently using the Azure subscription '$($account.name)'. Do you want to keep using it?" `
        -default_index 1
    
    if ($option -eq 2) {
        $accounts = az account list | ConvertFrom-Json | Sort-Object -Property name

        $account_list = $accounts | Select-Object -Property @{ label="displayName"; expression={ "$($_.name): $($_.id)" } }
        $option = Get-InputSelection `
            -options $account_list.displayName `
            -text "Choose a subscription to use from this list (using its Index):" `
            -separator "`r`n`r`n"

        $account = $accounts[$option - 1]

        Write-Host "Switching to Azure subscription '$($account.name)' with id '$($account.id)'."
        az account set -s $account.id
    }
}
function Set-ProjectName {
    param()

    $script:project_name = $null
    $script:resource_group_name = $null
    $script:create_resource_group = $false
    $first = $true

    while ([string]::IsNullOrEmpty($script:project_name) -or ($script:project_name -notmatch "^[a-z0-9]{5,10}$")) {
        if ($first -eq $false) {
            Write-Host "Use alphanumeric characters only"
        }
        else {
            Write-Host
            Write-Host "Provide a name that describes your project. This will be used to create the resource group and the deployment resources."
            $first = $false
        }
        $script:project_name = Read-Host -Prompt ">"

        $script:resource_group_name = "$($script:project_name)-rg"
        $resourceGroup = az group list | ConvertFrom-Json | Where-Object { $_.name -eq $script:resource_group_name }
        if (!$resourceGroup) {
            $script:create_resource_group = $true
        }
        else {
            $script:create_resource_group = $false
        }
    }
}

function Get-InputSelection {
    param(
        [array] $options,
        $text,
        $separator = "`r`n",
        $default_index = $null
    )

    Write-Host
    Write-Host $text -Separator "`r`n`r`n"
    $indexed_options = @()
    for ($index = 0; $index -lt $options.Count; $index++) {
        $indexed_options += ("$($index + 1): $($options[$index])")
    }

    Write-Host $indexed_options -Separator $separator

    if (!$default_index) {
        $prompt = ">"
    }
    else {
        $prompt = "> $default_index"
    }

    while ($true) {
        $option = Read-Host -Prompt $prompt
        try {
            if (!!$default_index -and !$option)  {
                $option = $default_index
                break
            }
            elseif ([int] $option -ge 1 -and [int] $option -le $options.Count) {
                break
            }
        }
        catch {
            Write-Host "Invalid index '$($option)' provided."
        }

        Write-Host
        Write-Host "Choose from the list using an index between 1 and $($options.Count)."
    }

    return $option
}