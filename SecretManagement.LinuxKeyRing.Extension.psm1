function Get-Secret {
	[CmdletBinding()]
	param(
		[string] $Name,
		[string] $VaultName,
		[hashtable] $AdditionalParameters
	)
	
	try {
		$result = & secret-tool lookup service "powershell-vault" account $Name 2>$null
		if ($LASTEXITCODE -eq 0 -and $result) {
			return [System.Security.SecureString](ConvertTo-SecureString -String $result -AsPlainText -Force)
		}
	}
	catch {
		Write-Error "Failed to retrieve secret '$Name': $($_.Exception.Message)"
	}
	return $null
}

function Set-Secret {
	[CmdletBinding()]
	param(
		[string] $Name,
		[object] $Secret,
		[string] $VaultName,
		[hashtable] $AdditionalParameters
	)
	
	try {
		$secretText = if ($Secret -is [System.Security.SecureString]) {
			[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret))
		} else {
			$Secret.ToString()
		}
		
		echo $secretText | & secret-tool store --label "PowerShell Secret: $Name" service "powershell-vault" account $Name
		return ($LASTEXITCODE -eq 0)
	}
	catch {
		Write-Error "Failed to store secret '$Name': $($_.Exception.Message)"
		return $false
	}
}

function Remove-Secret {
	[CmdletBinding()]
	param(
		[string] $Name,
		[string] $VaultName,
		[hashtable] $AdditionalParameters
	)
	
	try {
		& secret-tool clear service "powershell-vault" account $Name 2>$null
		return ($LASTEXITCODE -eq 0)
	}
	catch {
		Write-Error "Failed to remove secret '$Name': $($_.Exception.Message)"
		return $false
	}
}

function Get-SecretInfo {
	[CmdletBinding()]
	param(
		[string] $Filter,
		[string] $VaultName,
		[hashtable] $AdditionalParameters
	)
	
	try {
		$secrets = @()
		# Capture both stdout and stderr to get all output from secret-tool
		$searchOutput = $(& secret-tool search --all service "powershell-vault" 2>&1)
		if ($searchOutput) {
			$searchOutput | ForEach-Object {
				if ($_ -match "^attribute\.account = (.+)$") {
					$secretName = $Matches[1]
					if (-not $Filter -or $secretName -like "*$Filter*") {
						$secrets += [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
							$secretName,
							[Microsoft.PowerShell.SecretManagement.SecretType]::SecureString,
							$VaultName
						)
					}
				}
			}
		}
		return $secrets
	}
	catch {
		Write-Error "Failed to get secret info: $($_.Exception.Message)"
		return @()
	}
}

function Test-SecretVault {
	[CmdletBinding()]
	param(
		[string] $VaultName,
		[hashtable] $AdditionalParameters
	)
	
	try {
		# Test if secret-tool is available
		$null = Get-Command secret-tool -ErrorAction Stop
		return $true
	}
	catch {
		Write-Error "secret-tool command not found. Please install libsecret-tools."
		return $false
	}
}

function Unlock-SecretVault {
	[CmdletBinding()]
	param(
		[SecureString] $Password,
		[string] $VaultName,
		[hashtable] $AdditionalParameters
	)
	
	# Linux keyring unlocks automatically with desktop session
	# No password required - this is the key benefit of this vault
	return $true
}