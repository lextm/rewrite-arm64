#Requires -RunAsAdministrator

<#
.SYNOPSIS
Removes the copied IIS rewrite module DLLs.

.DESCRIPTION
This script deletes the `rewrite.dll` files from the IIS installation folders,
reverting the changes made by the patch script.

.NOTES
Requires administrative privileges.
#>

# IIS File Paths
$IIS32Path = Join-Path "$env:windir\SysWOW64\inetsrv" "rewrite.dll"
$IIS64Path = Join-Path "$env:windir\System32\inetsrv" "rewrite.dll"
$IISSchemaPath = Join-Path "$env:windir\System32\inetsrv\config\schema" "rewrite_schema.xml"
$ApplicationHostConfigPath = Join-Path "$env:windir\System32\inetsrv\config" "applicationHost.config"

function Remove-IISRewriteModule {
    <#
    .SYNOPSIS
    Deletes the copied IIS rewrite module files.
    #>

    try {
        # Delete 32-bit DLL
        if (Test-Path $IIS32Path) {
            Remove-Item -Path $IIS32Path -Force
            Write-Host "Deleted 32-bit rewrite.dll from: $IIS32Path"
        } else {
            Write-Warning "32-bit rewrite.dll not found: $IIS32Path"
        }

        # Delete 64-bit DLL
        if (Test-Path $IIS64Path) {
            Remove-Item -Path $IIS64Path -Force
            Write-Host "Deleted 64-bit rewrite.dll from: $IIS64Path"
        } else {
            Write-Warning "64-bit rewrite.dll not found: $IIS64Path"
        }

        Write-Host "IIS rewrite.dll files removed successfully."
    }
    catch {
        Write-Error "Failed to delete rewrite.dll files: $_"
    }
}

function Remove-IISRewriteSchema {
    try {
        if (Test-Path $IISSchemaPath) {
            Remove-Item -Path $IISSchemaPath -Force
            Write-Host "Deleted rewrite_schema.xml from IIS schema folder: $IISSchemaPath"
        } else {
            Write-Warning "rewrite_schema.xml not found in IIS schema folder: $IISSchemaPath"
        }
    }
    catch {
        Write-Error "Failed to delete rewrite_schema.xml: $_"
    }
}

function Remove-URLRewriteConfiguration {
    if (-not (Test-Path $ApplicationHostConfigPath)) {
        Write-Error "applicationHost.config not found at $ApplicationHostConfigPath"
        return
    }

    try {
        [xml]$config = Get-Content $ApplicationHostConfigPath

        # Remove rewrite section group from <configSections>
        $configSections = $config.configuration.'configSections'
        $systemWebServerGroup = $configSections.SelectSingleNode("sectionGroup[@name='system.webServer']")
        if ($systemWebServerGroup) {
            $rewriteGroup = $systemWebServerGroup.SelectSingleNode("sectionGroup[@name='rewrite']")
            if ($rewriteGroup) {
                $systemWebServerGroup.RemoveChild($rewriteGroup) | Out-Null
                Write-Host "Removed rewrite sectionGroup from system.webServer in configSections."
            } else {
                Write-Host "rewrite sectionGroup not found under system.webServer in configSections."
            }
        } else {
            Write-Host "system.webServer group not found in configSections."
        }

        # Remove global module for RewriteModule
        $globalModule = $config.configuration.'system.webServer'.globalModules.SelectSingleNode("add[@name='RewriteModule']")
        if ($globalModule) {
            $globalModule.ParentNode.RemoveChild($globalModule) | Out-Null
            Write-Host "Removed RewriteModule from globalModules."
        } else {
            Write-Host "RewriteModule not found in globalModules."
        }

        # Remove RewriteModule from <modules>
        $modules = $config.configuration.'system.webServer'.modules
        if ($modules) {
            $module = $modules.SelectSingleNode("add[@name='RewriteModule']")
            if ($module) {
                $modules.RemoveChild($module) | Out-Null
                Write-Host "Removed RewriteModule from modules."
            } else {
                Write-Host "RewriteModule not found in modules."
            }
        } else {
            Write-Host "<modules> not found."
        }

        # Save the updated configuration
        $config.Save($ApplicationHostConfigPath)
    }
    catch {
        Write-Error "Failed to remove URL Rewrite configuration: $_"
    }
}

# Run the Remove Process
Remove-IISRewriteModule
Remove-IISRewriteSchema
Remove-URLRewriteConfiguration
