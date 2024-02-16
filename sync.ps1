<#
    .NOTES
        ====================================================================================================
            Created on:     Feb 9 2024
            Created by:     John DeShano (deshanj@resa.net)
            Organization:   Wayne County Regional Education Agency
            Filename        sync.ps1
        ====================================================================================================

    .Synopsis
        Entra Computer Sync Utility

    .DESCRIPTION
        Syncs Entra Autopilot devices to Active Directory to allow for NPS device based authentication.

        The Entra App Registration needs the permission 'DeviceManagementServiceConfig.Read.All'

        A certificate can be generated using cert_tool.ps1

    .EXAMPLE
        powershell.exe -file sync.ps1
#>



# +------------+
# |   Config   |
# +------------+

# Entra Tenant ID
$entra_tenant_id = "";

# Entra Application Registration Application/Client ID
$entra_app_id = "";

# Entra Application Registration Certificate Subject
# This must match the subject name used in cert_tool.ps1
$entra_cert_subject = "Entra Computer Sync Utility";

# The issuer of the certificate that will be used for security attribute mapping
# EXAMPLE: DC=com,DC=google,CN=GOOGLE-CA-HERE
$cert_issuer = "";

# Active Directory base directory for Entra Sync computer objects
# Ensure the directory is strictly devices made by this script if you are deleting stale objects
# EXAMPLE: OU=Entra_Device_Sync,DC=google,DC=com
$ad_search_base = "";

# Logging directory
$logging_path = "$PSScriptRoot\output.log"



# +-------------+
# |   Startup   |
# +-------------+
Start-Transcript -Path $logging_path -NoClobber -Append | Out-null
Write-Host "Starting...`n" -ForegroundColor White


# +--------------------------+
# |   Install Dependencies   |
# +--------------------------+
Write-Host "Verifying dependencies..." -ForegroundColor White;
try {
    Get-PackageProvider -Name "NuGet" -Force | Out-Null;

    if (-not (Get-Module WindowsAutopilotIntune -ListAvailable)) {
        Install-Module WindowsAutopilotIntune -Force;
    }
    
    Import-Module WindowsAutopilotIntune -Scope Global;
}
catch {
    Write-Host "Failed to install dependencies Error:" -ForegroundColor Red
    Write-Error $_;
    Stop-Transcript
    exit 1;
}
Write-Host "Finished verifying dependencies...`n" -ForegroundColor Green;




# +-----------------------------------+
# |   Verify AD Organizational Unit   |
# +-----------------------------------+
Write-Host "Verifying AD search base '$ad_search_base'..." -ForegroundColor White;
try {
    Get-ADOrganizationalUnit -Identity $ad_search_base | Out-Null;
}
catch {
    Write-Host "Invalid search base '$ad_search_base' Error: " -ForegroundColor Red;
    Write-Error $_;
    Stop-Transcript
    exit 1;
}
Write-Host "Using '$ad_search_base' for Entra sync.`n" -ForegroundColor Green;



# +-----------------------+
# |   MSGraph API Setup   |
# +-----------------------+
Write-Host "Connecting to MSGraph API..." -ForegroundColor White
try {
    Connect-MgGraph -Tenant $entra_tenant_id -AppId $entra_app_id -CertificateName "CN=$entra_cert_subject" -NoWelcome -ErrorAction:Stop;
}
catch {
    Write-Host "Connection to MSGraph API failed. Error: " -ForegroundColor Red;
    Write-Error $_;
    Stop-Transcript
    exit 1;
}
Write-Host "Connected to MSGraph API successfully.`n" -ForegroundColor Green



# +---------------------------+
# |   Get Autopilot Devices   |
# +---------------------------+
Write-Host "Getting Entra autopilot devices..." -ForegroundColor White
$autopilot_devices;
try {
    $autopilot_devices = Get-AutopilotDevice -ErrorAction:Stop
}
catch {
    Write-Host "Failed to get Entra autopilot devices. Error:" -ForegroundColor Red;
    Write-Error $_
    Stop-Transcript
    exit 1;
}
Write-Host "Successfully retrieved Entra autopilot devices.`n" -ForegroundColor Green



# +------------------------------------+
# |   Create AD Computer Object Loop   |
# +------------------------------------+
Write-Host "Starting computer object creation..." -ForegroundColor White;
foreach ($autopilot_device in $autopilot_devices) {
    $device_id = $autopilot_device["azureActiveDirectoryDeviceId"];
    $device_spn = "HOST/$device_id";
    $device_sam = "$($device_id.Substring(0,19))";
    
    # +-------------------------------+
    # |   AD Object Duplicate Check   |
    # +-------------------------------+
    if (Get-ADComputer -Filter "Name -eq '$device_id'" -SearchBase $ad_search_base) {
        Write-Host "Skipping duplicate '$device_id'." -ForegroundColor Yellow;
        continue;
    }
    
    # +-------------------------------+
    # |   Create AD Computer Object   |
    # +-------------------------------+
    $new_ad_computer;
    try {
        Write-Host "Creating computer '$device_id'.";
        $new_ad_computer = New-ADComputer -Name $device_id -SAMAccountName $device_sam -ServicePrincipalNames $device_spn -Path $ad_search_base -PassThru;
    }
    catch {
        Write-Host "Failed to create computer object '$device_id'! Error: " -ForegroundColor Yellow;
        Write-Error $_;
        continue;
    }

    # +---------------------------------------------+
    # |   Update Computer Alt Security Identities   |
    # +---------------------------------------------+
    try {
        Write-Host "Updating computer alternate security identity." -ForegroundColor White
        Set-ADComputer -Identity $new_ad_computer -Add @{"altSecurityIdentities" = "X509:<I>$cert_issuer<S>CN=$device_id"} | Out-Null;
    }
    catch {
        Write-Host "Failed to update computer alternate security identity. Error:" -ForegroundColor Red;
        Write-Error $_;
        continue;
    }
}
Write-Host "Finished computer object creation...`n" -ForegroundColor Green;



# +--------------------------------------+
# |   AD Stale Computer Object Cleanup   |
# +--------------------------------------+
Write-Host "Starting stale computer object cleanup..." -ForegroundColor White;
$ad_computers = Get-ADComputer -Filter * -SearchBase $ad_search_base
foreach ($ad_computer in $ad_computers) {

    # Check AD computer object for corresponding autopilot device
    $obj_found = $false;
    foreach ($autopilot_device in $autopilot_devices) {
        if ($ad_computer["name"] -eq $autopilot_device["azureActiveDirectoryDeviceId"]) {
            $obj_found = $true
        }
    }

    # Device not found - stale
    if ($false -eq $obj_found) {
        Write-Host "Stale device '$($ad_computer['name'])' found, deleting..." -ForegroundColor Yellow;
        try {
            Remove-ADComputer -Identity $ad_computer -WhatIf
        }
        catch {
            Write-Host "Failed to delete computer object, Error: " -ForegroundColor Red
            Write-Error $_
        }
    }
}
Write-Host "Finished stale computer object cleanup...`n" -ForegroundColor Green;



# +----------+
# |   Exit   |
# +----------+
Write-Host "Finished, exiting..." -ForegroundColor White
Stop-Transcript
exit 0;