@{
    ModuleVersion = '1.0.0'
    RootModule = 'SecretManagement.LinuxKeyring.Extension.psm1'
    FunctionsToExport = @(
        'Export-Secret',
        'Get-Secret',
        'Get-SecretInfo',
        'Import-Secret',
        'Remove-Secret',
        'Set-Secret',
        'Test-SecretVault',
        'Unlock-SecretVault'
    )
}