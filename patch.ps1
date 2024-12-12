#Requires -RunAsAdministrator

<#
.SYNOPSIS
Verifies and installs the IIS rewrite module by copying DLLs from IIS Express if needed.

.DESCRIPTION
This script checks the existence and architecture of `rewrite.dll` files for both IIS and IIS Express installations.
If the rewrite module is missing in IIS, it copies the corresponding DLL files from IIS Express.

.NOTES
Requires administrative privileges.
#>

# File Paths
$IISExpress32Path = Join-Path "${env:ProgramFiles(x86)}" "IIS Express\rewrite.dll"
$IISExpress64Path = Join-Path "$env:ProgramFiles" "IIS Express\rewrite.dll"
$IIS32Path = Join-Path "$env:windir\SysWOW64\inetsrv" "rewrite.dll"
$IIS64Path = Join-Path "$env:windir\System32\inetsrv" "rewrite.dll"
$IISExpressSchemaPath = Join-Path "${env:ProgramFiles(x86)}\IIS Express\config\schema" "rewrite_schema.xml"
$IISSchemaPath = Join-Path "$env:windir\System32\inetsrv\config\schema" "rewrite_schema.xml"
$ApplicationHostConfigPath = Join-Path "$env:windir\System32\inetsrv\config" "applicationHost.config"

function Verify-IISExpressRewriteSchema {
    if (-not (Test-Path $IISExpressSchemaPath)) {
        Write-Host "rewrite_schema.xml missing in IIS Express schema folder: $IISExpressSchemaPath"
        return $false
    }

    Write-Host "rewrite_schema.xml exists in IIS Express schema folder."
    return $true
}

function Verify-IISRewriteSchema {
    if (-not (Test-Path $IISSchemaPath)) {
        Write-Host "rewrite_schema.xml missing in IIS schema folder: $IISSchemaPath"
        return $false
    }

    Write-Host "rewrite_schema.xml exists in IIS schema folder."
    return $true
}

function Verify-IISExpressRewriteModule {
    <#
    .SYNOPSIS
    Verifies the IIS Express rewrite module installation.
    #>

    # Validate Paths
    if (-not (Test-Path $IISExpress32Path) -or -not (Test-Path $IISExpress64Path)) {
        if (-not (Test-Path $IISExpress32Path)) {
            Write-Host "rewrite.dll missing in 32-bit IIS Express folder: $IISExpress32Path"
        }
        if (-not (Test-Path $IISExpress64Path)) {
            Write-Host "rewrite.dll missing in 64-bit IIS Express folder: $IISExpress64Path"
        }
        return $false
    }

    # Validate Architecture
    if ((Get-PEHeader -dllPath $IISExpress32Path) -ne "x86") {
        Write-Host "32-bit rewrite.dll in IIS Express is not x86: $IISExpress32Path"
        return $false
    }

    if ((Get-PEHeader -dllPath $IISExpress64Path) -ne "ARM64") {
        Write-Host "64-bit rewrite.dll in IIS Express is not ARM64: $IISExpress64Path"
        return $false
    }

    Write-Host "IIS Express rewrite.dll files are valid."
    return $true
}

function Verify-IISRewriteModule {
    <#
    .SYNOPSIS
    Verifies the IIS rewrite module installation.
    #>

    # Validate Paths
    if (-not (Test-Path $IIS32Path) -or -not (Test-Path $IIS64Path)) {
        if (-not (Test-Path $IIS32Path)) {
            Write-Host "rewrite.dll missing in 32-bit IIS folder: $IIS32Path"
        }
        if (-not (Test-Path $IIS64Path)) {
            Write-Host "rewrite.dll missing in 64-bit IIS folder: $IIS64Path"
        }
        return $false
    }

    # Validate Architecture
    if ((Get-PEHeader -dllPath $IIS32Path) -ne "x86") {
        Write-Host "32-bit rewrite.dll in IIS is not x86: $IIS32Path"
        return $false
    }

    if ((Get-PEHeader -dllPath $IIS64Path) -ne "ARM64") {
        Write-Host "64-bit rewrite.dll in IIS is not ARM64: $IIS64Path"
        return $false
    }

    Write-Host "IIS rewrite.dll files are valid."
    return $true
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

function Install-IISRewriteSchema {
    try {
        if (Test-Path $IISExpressSchemaPath) {
            Copy-Item -Path $IISExpressSchemaPath -Destination $IISSchemaPath -Force
            Write-Host "Copied rewrite_schema.xml to IIS schema folder: $IISSchemaPath"
        }
    }
    catch {
        Write-Error "Failed to copy rewrite_schema.xml: $_"
    }
}

function Install-IISRewriteModule {
    <#
    .SYNOPSIS
    Installs the IIS rewrite module by copying DLLs from IIS Express.
    #>

    try {
        if (Test-Path $IISExpress32Path) {
            Copy-Item -Path $IISExpress32Path -Destination $IIS32Path -Force
            Write-Host "Copied 32-bit rewrite.dll to IIS folder: $IIS32Path"
        }
        if (Test-Path $IISExpress64Path) {
            Copy-Item -Path $IISExpress64Path -Destination $IIS64Path -Force
            Write-Host "Copied 64-bit rewrite.dll to IIS folder: $IIS64Path"
        }
    }
    catch {
        Write-Error "Failed to copy rewrite.dll: $_"
    }
}

function Add-URLRewriteConfiguration {
    <#
    .SYNOPSIS
    Ensures all required sections for URL Rewrite are added to applicationHost.config.
    #>

    if (-not (Test-Path $ApplicationHostConfigPath)) {
        Write-Error "applicationHost.config not found at $ApplicationHostConfigPath"
        return
    }

    try {
        [xml]$config = Get-Content $ApplicationHostConfigPath

        # Add section group to <configSections> under system.webServer
        $configSections = $config.configuration.'configSections'
        $systemWebServerGroup = $configSections.SelectSingleNode("sectionGroup[@name='system.webServer']")
        if (-not $systemWebServerGroup) {
            Write-Error "The system.webServer section group does not exist in configSections. Exiting."
            return
        }

        $rewriteGroup = $systemWebServerGroup.SelectSingleNode("sectionGroup[@name='rewrite']")
        if (-not $rewriteGroup) {
            $rewriteGroup = $config.CreateElement("sectionGroup")
            $rewriteGroup.SetAttribute("name", "rewrite")
            $sections = @(
                @{ name = "allowedServerVariables"; overrideModeDefault = "Deny" },
                @{ name = "rules"; overrideModeDefault = "Allow" },
                @{ name = "outboundRules"; overrideModeDefault = "Allow" },
                @{ name = "globalRules"; overrideModeDefault = "Deny"; allowDefinition = "AppHostOnly" },
                @{ name = "providers"; overrideModeDefault = "Allow" },
                @{ name = "rewriteMaps"; overrideModeDefault = "Allow" }
            )
            foreach ($section in $sections) {
                $node = $config.CreateElement("section")
                $node.SetAttribute("name", $section.name)
                $node.SetAttribute("overrideModeDefault", $section.overrideModeDefault)
                if ($section.ContainsKey("allowDefinition")) {
                    $node.SetAttribute("allowDefinition", $section.allowDefinition)
                }
                $rewriteGroup.AppendChild($node) | Out-Null
            }
            $systemWebServerGroup.AppendChild($rewriteGroup) | Out-Null
            Write-Host "Added rewrite sectionGroup to system.webServer in configSections."
        } else {
            Write-Host "rewrite sectionGroup already exists in system.webServer configSections."
        }

        # Add global module for RewriteModule
        $globalModules = $config.configuration.'system.webServer'.globalModules
        if (-not $globalModules.SelectSingleNode("add[@name='RewriteModule']")) {
            $globalModule = $config.CreateElement("add")
            $globalModule.SetAttribute("name", "RewriteModule")
            $globalModule.SetAttribute("image", "%windir%\System32\inetsrv\rewrite.dll")
            $globalModules.AppendChild($globalModule) | Out-Null
            Write-Host "Added RewriteModule to globalModules."
        } else {
            Write-Host "RewriteModule already exists in globalModules."
        }

        # Add RewriteModule to <modules>
        $modules = $config.configuration.'system.webServer'.modules
        if (-not $modules) {
            $modules = $config.CreateElement("modules")
            $location.AppendChild($modules) | Out-Null
        }

        if (-not $modules.SelectSingleNode("add[@name='RewriteModule']")) {
            $module = $config.CreateElement("add")
            $module.SetAttribute("name", "RewriteModule")
            $modules.AppendChild($module) | Out-Null
            Write-Host "Added RewriteModule to modules."
        } else {
            Write-Host "RewriteModule already exists in modules."
        }

        # Save the updated configuration
        $config.Save($ApplicationHostConfigPath)
    }
    catch {
        Write-Error "Failed to add URL Rewrite configuration: $_"
    }
}


# Example Usage
$iisExpressReady = Verify-IISExpressRewriteModule
$iisReady = Verify-IISRewriteModule

if (-not $iisExpressReady) {
    Write-Host "IIS Express rewrite module is not ready. You need to install VS 2022 for Windows Arm64 in advance. Exit."
    exit 1
}

if ($iisReady) {
    Write-Host "IIS rewrite module is already installed. If already patched, run restore.ps1. Exit."
    exit 0
}

Write-Host "Copying IIS rewrite module from IIS Express to IIS..."
Install-IISRewriteModule
Install-IISRewriteSchema
Add-URLRewriteConfiguration
Write-Host "Installation complete."
