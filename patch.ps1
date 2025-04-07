#Requires -RunAsAdministrator

<#
.SYNOPSIS
Patches the IIS URL Rewrite module by replacing the 64-bit DLL with ARM64 version from IIS Express.

.DESCRIPTION
This script first checks if URL Rewrite module is installed via its MSI GUID. If installed,
it verifies if the 64-bit rewrite.dll is compatible with ARM64. If not compatible, it creates
a backup of the original DLL and replaces it with the ARM64 version from IIS Express.

.NOTES
Requires administrative privileges.
#>

# File Paths
$IISExpress64Path = Join-Path "$env:ProgramFiles" "IIS Express\rewrite.dll"
$IIS64Path = Join-Path "$env:windir\System32\inetsrv" "rewrite.dll"
$BackupPath = Join-Path "$env:windir\System32\inetsrv" "rewrite.dll.bak"
$ApplicationHostConfigPath = Join-Path "$env:windir\System32\inetsrv\config" "applicationHost.config"

# URL Rewrite Module MSI GUIDs
$urlRewriteGuids = @(
    "9BCA2118-F753-4A1E-BCF3-5A820729965C"
)

function Check-URLRewriteInstalled {
    <#
    .SYNOPSIS
    Checks if URL Rewrite module is installed via its MSI GUID.
    #>
    foreach ($guid in $urlRewriteGuids) {
        $installed = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{$guid}" -ErrorAction SilentlyContinue
        if ($installed) {
            Write-Host "URL Rewrite Module is installed (GUID: $guid)"
            return $true
        }

        # Check 32-bit registry on 64-bit systems
        $installed = Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{$guid}" -ErrorAction SilentlyContinue
        if ($installed) {
            Write-Host "URL Rewrite Module is installed (32-bit registry) (GUID: $guid)"
            return $true
        }
    }

    Write-Host "URL Rewrite Module is not installed"
    return $false
}

function Get-PEHeader {
    <#
    .SYNOPSIS
    Reads the architecture of a PE file.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$dllPath
    )

    try {
        $stream = [System.IO.File]::OpenRead($dllPath)
        $reader = New-Object System.IO.BinaryReader($stream)

        try {
            $stream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) > $null
            $peOffset = $reader.ReadInt32()

            $stream.Seek($peOffset, [System.IO.SeekOrigin]::Begin) > $null
            if ($reader.ReadUInt32() -ne 0x00004550) { # "PE\0\0"
                throw "Not a valid PE file."
            }

            switch ($reader.ReadUInt16()) {
                0x014c { return "x86" }
                0x8664 { return "x64" }
                0xAA64 { return "ARM64" }
                0x01c4 { return "ARM" }
                0xA641 { return "ARM64X" }
                default { return "Unknown architecture" }
            }
        }
        finally {
            $reader.Close()
            $stream.Close()
        }
    }
    catch {
        Write-Error "Error reading PE header from $dllPath : $_"
        return "Unknown"
    }
}

function Verify-IISExpressRewriteModule {
    <#
    .SYNOPSIS
    Verifies the IIS Express 64-bit rewrite module is ARM64 compatible.
    #>

    # Validate Path
    if (-not (Test-Path $IISExpress64Path)) {
        Write-Host "rewrite.dll missing in 64-bit IIS Express folder: $IISExpress64Path"
        return $false
    }

    # Validate Architecture
    if ((Get-PEHeader -dllPath $IISExpress64Path) -ne "ARM64") {
        Write-Host "64-bit rewrite.dll in IIS Express is not ARM64: $IISExpress64Path"
        return $false
    }

    Write-Host "IIS Express 64-bit rewrite.dll is valid ARM64."
    return $true
}

function Verify-IISRewriteModule {
    <#
    .SYNOPSIS
    Verifies the IIS 64-bit rewrite module architecture.
    #>

    # Validate Path
    if (-not (Test-Path $IIS64Path)) {
        Write-Host "rewrite.dll missing in 64-bit IIS folder: $IIS64Path"
        return $false
    }

    # Get Architecture
    $architecture = Get-PEHeader -dllPath $IIS64Path
    
    if ($architecture -eq "ARM64") {
        Write-Host "64-bit rewrite.dll in IIS is already ARM64 compatible: $IIS64Path"
        return $true
    } else {
        Write-Host "64-bit rewrite.dll in IIS is $architecture, needs to be replaced with ARM64 version"
        return $false
    }
}

function Backup-IISRewriteModule {
    <#
    .SYNOPSIS
    Creates a backup of the original IIS 64-bit rewrite module.
    #>

    try {
        if (Test-Path $IIS64Path) {
            if (-not (Test-Path $BackupPath)) {
                Copy-Item -Path $IIS64Path -Destination $BackupPath -Force
                Write-Host "Created backup of 64-bit rewrite.dll: $BackupPath"
                return $true
            } else {
                Write-Host "Backup of rewrite.dll already exists: $BackupPath"
                return $true
            }
        } else {
            Write-Host "Cannot backup, source file doesn't exist: $IIS64Path"
            return $false
        }
    }
    catch {
        Write-Error "Failed to create backup of rewrite.dll: $_"
        return $false
    }
}

function Patch-IISRewriteModule {
    <#
    .SYNOPSIS
    Replaces the 64-bit rewrite.dll with ARM64 version from IIS Express.
    #>

    try {
        if (Test-Path $IISExpress64Path) {
            Copy-Item -Path $IISExpress64Path -Destination $IIS64Path -Force
            Write-Host "Patched 64-bit rewrite.dll with ARM64 version from IIS Express"
            return $true
        } else {
            Write-Host "Cannot patch, source ARM64 file doesn't exist: $IISExpress64Path"
            return $false
        }
    }
    catch {
        Write-Error "Failed to patch rewrite.dll: $_"
        return $false
    }
}

# Main script execution
if (-not (Check-URLRewriteInstalled)) {
    Write-Host "URL Rewrite module is not installed. Please install it first. Exit."
    exit 1
}

$iisExpressReady = Verify-IISExpressRewriteModule
if (-not $iisExpressReady) {
    Write-Host "IIS Express ARM64 rewrite module is not available. You need to install VS 2022 for Windows Arm64 in advance. Exit."
    exit 1
}

$needsPatch = -not (Verify-IISRewriteModule)
if (-not $needsPatch) {
    Write-Host "IIS 64-bit rewrite.dll is already ARM64 compatible. No patching needed. Exit."
    exit 0
}

Write-Host "Preparing to patch IIS URL Rewrite module with ARM64 version..."
&iisreset /stop

$backupSuccess = Backup-IISRewriteModule
if (-not $backupSuccess) {
    Write-Host "Failed to create backup. Cannot proceed with patching. Exit."
    &iisreset /start
    exit 1
}

$patchSuccess = Patch-IISRewriteModule
if ($patchSuccess) {
    Write-Host "Successfully patched IIS URL Rewrite module with ARM64 version."
} else {
    Write-Host "Failed to patch IIS URL Rewrite module."
    &iisreset /start
    exit 1
}

&iisreset /start
Write-Host "IIS URL Rewrite module patched successfully. Original DLL backed up at $BackupPath"