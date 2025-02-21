# rewrite-arm64, installer patches for URL Rewrite module on Windows 11 ARM64 and IIS.

## ⚠️ License Notice

This patch extracts and utilizes components from **IIS 10.0 Express** to enable ARM64 compatible URL Rewrite support on a developer's Windows machine. Please be aware of the following:

1. **IIS 10.0 Express is licensed by Microsoft for development and testing purposes only.** It is not intended for use in production environments.
2. **Redistribution of IIS 10.0 Express components** is prohibited by the license agreement. So before using this patch, you agree to download and install IIS 10.0 Express from official Microsoft sources as part of Visual Studio 2022 and acknowledge that the components are used solely on your machine for **development and testing**.
3. If you plan to use this solution in a production environment, you must **obtain the necessary licenses** from Microsoft or seek alternative methods that comply with their terms.

For detailed information, please review the entire IIS 10.0 Express License Agreement before proceeding. This license agreement file is located at `%ProgramFiles%\IIS Express\license.rtf` after you install IIS 10.0 Express.

## Background
The official installer for IIS URL Rewrite module installs only x86 and x64 bits of `rewrite.dll` on the machine, so that only emulated x64 and x86 web apps can run on IIS with URL rewrite rules. The application pool simply crashes when you try to host ARM64 web apps. This brings some minor trouble to web developers who want to run end-to-end testing of their web apps in ARM64 bitness. Since Windows Server hasn't have an ARM64 release yet to host ARM64 bitness web apps in production, this limitation is understandable.

### Why Pure ARM64 Bitness?
Running web apps in pure ARM64 bitness offers several benefits:
- **Performance Boost**: Pure ARM64 apps avoid x64 emulation overhead, leading to better performance and lower power consumption, especially on ARM-based devices like the Copilot PCs.
- **Consistent End-to-End Testing**: Ensures consistent testing for developers targeting ARM64 client devices, allowing early detection of architecture-specific issues.
- **Future-Proofing**: As ARM64 adoption grows, developers can future-proof their applications by preparing for native ARM64 deployment.

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

## Technical Support

This patch is maintained and supported within this GitHub repository. If you encounter issues, have questions, or need help with the patch, please:
- **Open an issue** in this repository.
- **Search existing issues** to see if your question has already been addressed.

Please be aware of the following:
- **Microsoft does not provide support** for this patch or any components extracted from IIS 10.0 Express for ARM64 compatibility.
- This patch is provided "as-is" without any guarantees, and you are using it at your own risk.

For any general issues related to IIS 10.0 Express or URL Rewrite module, please refer to the [official Microsoft documentation](https://learn.microsoft.com/en-us/iis/extensions/url-rewrite-module/using-the-url-rewrite-module) and support channels.
