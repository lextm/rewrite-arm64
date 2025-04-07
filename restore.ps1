#Requires -RunAsAdministrator

<#
.SYNOPSIS
Restores the original IIS URL Rewrite module from backup.

.DESCRIPTION
This script restores the original IIS URL Rewrite module DLL from the backup 
created during the patching process.

.NOTES
Requires administrative privileges.
#>

# File Paths
$IIS64Path = Join-Path "$env:windir\System32\inetsrv" "rewrite.dll"
$BackupPath = Join-Path "$env:windir\System32\inetsrv" "rewrite.dll.bak"

function Restore-IISRewriteModule {
    <#
    .SYNOPSIS
    Restores the original 64-bit rewrite.dll from backup.
    #>
    try {
        if (Test-Path $BackupPath) {
            Copy-Item -Path $BackupPath -Destination $IIS64Path -Force
            Write-Host "Restored original 64-bit rewrite.dll from backup"
            return $true
        } else {
            Write-Host "Cannot restore, backup file doesn't exist: $BackupPath"
            return $false
        }
    }
    catch {
        Write-Error "Failed to restore rewrite.dll from backup: $_"
        return $false
    }
}

# Main script execution

Write-Host "Preparing to restore original IIS URL Rewrite module from backup..."

if (-not (Test-Path $BackupPath)) {
    Write-Host "No backup file found at $BackupPath. Cannot restore from backup."
    Write-Host "Please reinstall the URL Rewrite module manually:"
    Write-Host "1. Download the official URL Rewrite module installer from Microsoft:"
    Write-Host "   https://www.iis.net/downloads/microsoft/url-rewrite"
    Write-Host "2. Uninstall any existing URL Rewrite module from Control Panel"
    Write-Host "3. Run the downloaded installer to reinstall the module"
    exit 1
}

&iisreset /stop
$restoreSuccess = Restore-IISRewriteModule
&iisreset /start
if ($restoreSuccess) {
    Write-Host "Successfully restored original IIS URL Rewrite module."
    # Delete the backup file after successful restoration
    try {
        Remove-Item -Path $BackupPath -Force
        Write-Host "Backup file deleted successfully."
    }
    catch {
        Write-Warning "Could not delete backup file: $_"
    }
} else {
    Write-Host "Failed to restore IIS URL Rewrite module."
    Write-Host "Please reinstall the URL Rewrite module manually:"
    Write-Host "1. Download the official URL Rewrite module installer from Microsoft:"
    Write-Host "   https://www.iis.net/downloads/microsoft/url-rewrite"
    Write-Host "2. Uninstall any existing URL Rewrite module from Control Panel"
    Write-Host "3. Run the downloaded installer to reinstall the module"
    exit 1
}

Write-Host "IIS URL Rewrite module restored successfully."