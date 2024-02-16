# EntraDeviceSync
Creates Active Directory computer objects from Entra autopilot devices for NPS

## Generate Entra Application Certificate
The `cert_tool.ps1` file contains variables that can be configured, or can just be run on its own.

```shell
powershell.exe -file cert_tool.ps1
```

If there is already a certificate with the same subject, or the certificate file already exists, the user will be prompted to delete the old one and replace it.

Apon completion, a script will be placed in the same folder as the script.

## Create Entra Application

1. Browse to https://entra.microsoft.com/ and login
2. Navigate to App registrations
3. Create a new registration
4. Under 'Certificates & secrets' upload the certificate generated previously
5. Under 'API permissions' add `DeviceManagementServiceConfig.Read.All` and grant admin consent

## Configure Sync Script

Edit the `sync.ps1` file