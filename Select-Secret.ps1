function Select-Secret {
	[CmdletBinding()]
	param (
		[parameter(Mandatory=$false)][string]$VaultName
	)

	if ([string]::IsNullOrEmpty($VaultName)) {
		$vaults = Get-SecretVault
		if ($vaults.Count -eq 0) {
			Write-Warning "No Secret Vaults Found, Please create one with New-SecretVault"
			break
		} else {
			$vault = Out-GridSelect -InputObject $vaults -Title "Select Secret Vault"
		}
		if ($vault) {
			$VaultName = $vault.Name
		}
	}
	if ($VaultName) {
		$keys = Get-SecretInfo -Vault $VaultName
		$key = Out-GridSelect -InputObject $keys -Title "Select Secret from Vault: $VaultName"

		if ($key) {
			Write-Host "Key Selected: $($key.Name) type = $($key.Type)" -ForegroundColor Green
			if ($key.Type -in ("String","SecureString")) {
				Get-Secret -Vault $VaultName -Name $key.Name -AsPlainText
			} else {
				$cred = Get-Secret -Vault $VaultName -Name $key.Name
				@{UserName = $cred.UserName; Password = $cred.GetNetworkCredential().Password} | ConvertTo-Json -Compress
			}
		}
	}
}
