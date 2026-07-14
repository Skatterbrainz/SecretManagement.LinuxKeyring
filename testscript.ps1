$vaultname = "LinuxKeyring"
$localModuleManifest = Join-Path -Path $PSScriptRoot -ChildPath "SecretManagement.LinuxKeyring.psd1"

if (-not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
    Install-Module -Name Microsoft.PowerShell.SecretManagement -Scope CurrentUser -Force
}

if (-not (Get-Module -ListAvailable -Name SecretManagement.LinuxKeyring)) {
    Install-Module -Name SecretManagement.LinuxKeyring -Scope CurrentUser -Force
}

Import-Module -Name Microsoft.PowerShell.SecretManagement -Force

# Prefer the local workspace module during development to avoid loading an older installed copy.
if (Test-Path -Path $localModuleManifest) {
    Remove-Module SecretManagement.LinuxKeyring -ErrorAction SilentlyContinue
    Import-Module -Name $localModuleManifest -Force
}
else {
    Import-Module -Name SecretManagement.LinuxKeyring -Force
}

Write-Output "Loaded module path: $((Get-Module -Name SecretManagement.LinuxKeyring).Path)"

$localModulePath = Split-Path -Path $localModuleManifest -Parent
$vault = Get-SecretVault -Name $vaultname -ErrorAction SilentlyContinue

if (-not $vault) {
    Write-Output "Registering secret vault '$vaultname'..."
    Register-SecretVault -Name $vaultname -ModuleName $localModuleManifest -DefaultVault -ErrorAction Stop
}
elseif ($vault.ModulePath -ne $localModulePath) {
    Write-Output "Vault '$vaultname' is registered to '$($vault.ModulePath)'. Re-registering to local module path '$localModulePath'..."
    Unregister-SecretVault -Name $vaultname -ErrorAction Stop
    Register-SecretVault -Name $vaultname -ModuleName $localModuleManifest -DefaultVault -ErrorAction Stop
}
else {
    Write-Output "Secret vault '$vaultname' is already registered."
}

$username1 = "testuser"
$password1 = "P@ssw0rd54321"
$credential = New-Object System.Management.Automation.PSCredential ($username1, (ConvertTo-SecureString $password1 -AsPlainText -Force))

Write-Output "Storing secret for user '$username1'..."
Set-Secret -Name "TestUser" -Vault $vaultname -Secret $credential

Write-Output "Retrieving secret for user '$username1'..."
$cred = Get-Secret -Name "TestUser" -Vault $vaultname

if ($cred -is [System.Management.Automation.PSCredential]) {
    Write-Output "Retrieved credential is of type PSCredential."
    $cred.UserName
    $cred.GetNetworkCredential().Password
} else {
    Write-Output "Retrieved credential is of type: $($cred.GetType().FullName)."
}

Remove-Secret -Name "TestUser" -Vault $vaultname -ErrorAction SilentlyContinue
Write-Output "Removed secret for user '$username1'."

$secstring = "this is a test string" | ConvertTo-SecureString -AsPlainText -Force
Write-Output "Storing a secure string secret..."
Set-Secret -Name "TestString" -Vault $vaultname -Secret $secstring

Write-Output "Retrieving the secure string secret..."
$retrievedSecString = Get-Secret -Name "TestString" -Vault $vaultname -AsPlainText
Write-Output "Retrieved secure string: $retrievedSecString"

Remove-Secret -Name "TestString" -Vault $vaultname -ErrorAction SilentlyContinue
Write-Output "Removed secure string secret."