<#
    .NOTES
        ====================================================================================================
            Created on:     Feb 9 2024
            Created by:     John DeShano (deshanj@resa.net)
            Organization:   Wayne County Regional Education Agency
            Filename        create_cert.ps1
        ====================================================================================================
    
    .Synopsis
        Create a certificate for Entra API
    
    .DESCRIPTION
        Creates a self signed certificate for authentication to Microsoft Entra MSGraph API.
        
        By default, the certificate is made, and stored in the local computer certificate store.
        After creation, the public cert is exported to the same path as the powershell script.
        
        If the script fails, ensure the user running the script has permissions to the path of the script.

    .EXAMPLE
        powershell.exe -file create_cert.ps1
#>



# +------------+
# |   Config   |
# +------------+
# Export directory of the certificate, by default in the same directory as the script
$cert_export_path = "$PSScriptRoot\api_certificate.cer"

# !WARNING: This needs to match 'entra_cert_subject' in the sync script as well
$cert_subject = "Entra Computer Sync Utility"

# The Cert Store to use
$cert_store = "Cert:\LocalMachine\My";

# Validity period of the certificate, 12 months by default
$cert_validity_months = 12;



# +---------------------------------+
# |   Duplicate Certificate Check   |
# +---------------------------------+
Write-Host "Starting certificate duplicate check..." -ForegroundColor White;

$current_certs = Get-ChildItem -Path $cert_store | Select-Object *
foreach ($current_cert in $current_certs) {
    if ($current_cert.Subject -eq "CN=$cert_subject") {
        Write-Host "A certficiate with the subject '$cert_subject' already exists in the '$cert_store' cert store." -ForegroundColor Yellow;
        
        while ($true) {
            Write-Host "Would you like to delete and replace the certificate? " -ForegroundColor Yellow -NoNewline
            $input_delete_cert = Read-Host "(y/n)";
            if ($input_delete_cert -eq "y") {
                try {
                    Write-Host "Deleting certificate from '$cert_store'..." -ForegroundColor White;
                    $current_cert | Remove-Item
                    break;
                }
                catch {
                    Write-Host "Failed to delete certificate. Error: " -ForegroundColor Red;
                    Write-Error $_;
                    exit 1;
                }
            }
            elseif ($input_delete_cert -eq "n") {
                Write-Host "Exiting..." -ForegroundColor White;
                exit 0;
            }
        }
    }
}



# +------------------------------------------+
# |   New-SelfSignedCertificate Properties   |
# +------------------------------------------+
$cert_properties = @{
    Subject           = "CN=$cert_subject"
    CertStoreLocation = $cert_store
    HashAlgorithm     = "sha256"
    KeyExportPolicy   = "NonExportable"
    KeyUsage          = "DigitalSignature"
    KeyAlgorithm      = "RSA"
    KeyLength         = 2048
    KeySpec           = "Signature"
    NotAfter          = (Get-Date).AddMonths($cert_validity_months)
    TextExtension     = @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
};



# +------------------------+
# |   Create Certificate   |
# +------------------------+
Write-Host "Starting certificate creation..." -ForegroundColor White;

$cert;
try {
    $cert = New-SelfSignedCertificate @cert_properties;
    Write-Host "Certificate created successfully." -ForegroundColor Green;
}
catch {
    Write-Host "Certificate creation failed! Error: " -ForegroundColor Red;
    Write-Error $_;
    exit 1;
}



# +------------------------------------------+
# |   Certificate Export Path Verficiation   |
# +------------------------------------------+
Write-Host "Starting certificate export verification..." -ForegroundColor White;
if (Test-Path -Path $cert_export_path) {
    Write-Host "A file already exists at '$cert_export_path'..." -ForegroundColor Yellow;
    while ($true) {
        Write-Host "Would you like to delete and replace this file? " -ForegroundColor Yellow -NoNewline
        $input_delete_file = Read-Host "(y/n)"

        if ($input_delete_file -eq "y") {
            try {
                Write-Host "Deleting file '$cert_export_path'" -ForegroundColor White;
                Remove-Item -Path $cert_export_path
                break;
            }
            catch {
                Write-Host "Failed to delete file '$cert_export_path' Error:" -ForegroundColor Red
                Write-Error $_;
                exit 1;
            }
        }if ($input_delete_file -eq "n") {
            Write-Host "Exiting..." -ForegroundColor Yellow;
            exit 0;
        }
    }
}



# +------------------------+
# |   Certificate Export   |
# +------------------------+
Write-Host "Starting certificate export..."
try {
    Write-Host "Exporting certificate to '$cert_export_path'";
    Export-Certificate -Cert $cert -FilePath $cert_export_path | Out-Null;
    Write-Host "Certificate exported successfully." -ForegroundColor Green;
}
catch {
    Write-Host "Certificate export failed. Error:" -ForegroundColor Red;
    Write-Error $_;
    exit 1
}



# +----------+
# |   Exit   |
# +----------+
exit 0;