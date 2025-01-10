# OfflineLanguageInstaller

`OfflineLanguageInstaller` is a PowerShell module designed to facilitate the offline installation of language pack feature on Windows 11 using an ISO file. This module simplifies the process of adding new language features to your system without requiring an internet connection, making it ideal for environments with limited or no internet access.

The module was tested on a freshly Hyper-V box running Windows 11 23H2.

## Features

- **Offline Installation**: Install language pack features from an ISO file without needing an internet connection.
- **Ease of Use**: Simple usage of one command exposed, which is `Install-LanguageFromIso`

## Installation

This module is published to the PSGallery. You can install the module on Windows PowerShell 5.1 and PowerShell 7+ using the following command:

```powershell
# Windows PowerShell using PowerShellGet
Install-Module -Name OfflineLanguageInstaller

# PowerShell 7+ using Microsoft.PowerShell.PSResourceGet
Install-PSResource -Name OfflineLanguageInstaller
```

> [!NOTE]
> The module requires both `PSDesiredStateConfiguration` and `PSDscResources` module. When installing the module through PowerShell Gallery, these modules will be automatically installed.

## Usage examples

To get started with the `OfflineLanguageInstaller` module, you can first inspect the examples by running:

```powershell
# Get examples
Get-Help -Name Install-LanguageFromIso -Examples

# Run one of the examples
Install-LanguageFromIso -IsoPath 'C:\ISOs\26100.1.240331-1435.ge_release_amd64fre_CLIENT_LOF_PACKAGES_OEM.iso' -LanguageCode 'en-us'
```

## Additional notes

To find the available ISOs for Windows 11 containing the language CAB files, check out this [link](https://learn.microsoft.com/en-us/azure/virtual-desktop/windows-11-language-packs#prerequisites).

## Link

To see it in action, check out the blog post on this [link](https://medium.com/@gijsreijn/how-to-quick-and-easy-install-languages-features-for-windows-11-90c99b88f677).

## Contributing

Contributions are welcome! Please follow these steps to contribute:

1. Fork the repository
2. Create a new branch (git checkout -b feature-branch)
3. Make your changes
4. Commit your changes (git commit -m 'Add some feature')
5. Push to the branch (git push origin feature-branch)
6. Open a pull request

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Contact

For any questions or suggestions, please open an issue.
