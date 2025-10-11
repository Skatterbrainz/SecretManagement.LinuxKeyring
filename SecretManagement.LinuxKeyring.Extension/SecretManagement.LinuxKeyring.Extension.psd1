@{
    ModuleVersion = '1.0.0'
    RootModule = 'SecretManagement.LinuxKeyring.Extension.psm1'
    FunctionsToExport = @(
        'Get-Secret',
        'Get-SecretInfo',
        'Remove-Secret',
        'Set-Secret',
        'Test-SecretVault',
        'Unlock-SecretVault'
    )
}