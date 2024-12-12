# rewrite-arm64, installer patches for URL Rewrite module on Windows 11 ARM64 and IIS.

## Background
The official installer for IIS URL Rewrite module only properly installs x86 and x64 bits on the machine, so that only emulated x64 and x86 web apps can run on IIS with URL rewrite rules. The application pool simply crashes when you try to host ARM64 web apps.

## Preparation

Perform the following steps to prepare the environment on your development machine,

1. Download and install [Arm64 Visual Studio](https://learn.microsoft.com/en-us/visualstudio/install/visual-studio-on-arm-devices?view=vs-2022) from Microsoft.

   > Commonly you install IIS Express by adding one of the workloads, such as "ASP.NET and web development".

1. Install IIS.
1. If you have already installed a previous version of IIS URL Rewrite module from its MSI package, uninstall it.

## Apply the Patch

1. Clone this repo to your local disk.
1. Execute `patch.ps1` as administrator so that it extracts the necessary files from IIS Express and install to the desired places.

## Restore to Default

1. Execute `restore.ps1` as administrator.
