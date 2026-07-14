function ConvertFrom-SecureStringPlainText {
	param(
		[Parameter(Mandatory)]
		[System.Security.SecureString] $SecureString
	)

	$ptr = [System.IntPtr]::Zero
	try {
		$ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
		return [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
	}
	finally {
		if ($ptr -ne [System.IntPtr]::Zero) {
			[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
		}
	}
}

function Resolve-SecretPayloadText {
	param(
		[Parameter(Mandatory)]
		[object] $RawValue
	)

	if ($null -eq $RawValue) {
		return $null
	}

	$payloadText = if ($RawValue -is [System.Array]) {
		($RawValue | ForEach-Object { [string]$_ }) -join [System.Environment]::NewLine
	}
	else {
		[string]$RawValue
	}

	return $payloadText.Trim("`0", "`r", "`n", " ", "`t")
}

function ConvertTo-SecretPayload {
	param(
		[Parameter(Mandatory)]
		[object] $Secret
	)

	$payloadPrefix = "SM-LINUXKEYRING::"
	$payloadObject = $null

	if ($Secret -is [pscredential]) {
		$payloadObject = [ordered]@{
			SchemaVersion = 1
			Type = "PSCredential"
			UserName = $Secret.UserName
			Password = ConvertFrom-SecureStringPlainText -SecureString $Secret.Password
		}
	}
	elseif ($Secret -is [System.Security.SecureString]) {
		$payloadObject = [ordered]@{
			SchemaVersion = 1
			Type = "SecureString"
			Value = ConvertFrom-SecureStringPlainText -SecureString $Secret
		}
	}
	elseif ($Secret -is [string]) {
		$payloadObject = [ordered]@{
			SchemaVersion = 1
			Type = "String"
			Value = $Secret
		}
	}
	else {
		$payloadObject = [ordered]@{
			SchemaVersion = 1
			Type = "String"
			Value = $Secret.ToString()
		}
	}

	return $payloadPrefix + ($payloadObject | ConvertTo-Json -Compress)
}

function ConvertFrom-SecretPayload {
	param(
		[Parameter(Mandatory)]
		[string] $Payload
	)

	$normalizedPayload = Resolve-SecretPayloadText -RawValue $Payload
	$payloadPrefix = "SM-LINUXKEYRING::"
	if (-not $normalizedPayload.StartsWith($payloadPrefix, [System.StringComparison]::Ordinal)) {
		# Backward compatibility with older versions that stored plaintext only.
		# Also tolerate JSON payloads that may not include our prefix.
		try {
			$secretObject = $normalizedPayload | ConvertFrom-Json -ErrorAction Stop
			if ($secretObject.Type -eq "PSCredential") {
				$password = ConvertTo-SecureString -String $secretObject.Password -AsPlainText -Force
				return [pscredential]::new($secretObject.UserName, $password)
			}
			if ($secretObject.Type -eq "String") {
				return [string]$secretObject.Value
			}
			if ($secretObject.Type -eq "SecureString") {
				return [System.Security.SecureString](ConvertTo-SecureString -String $secretObject.Value -AsPlainText -Force)
			}
		}
		catch {
		}

		return [System.Security.SecureString](ConvertTo-SecureString -String $normalizedPayload -AsPlainText -Force)
	}

	$json = $normalizedPayload.Substring($payloadPrefix.Length)
	$secretObject = $json | ConvertFrom-Json

	switch ($secretObject.Type) {
		"PSCredential" {
			$password = ConvertTo-SecureString -String $secretObject.Password -AsPlainText -Force
			return [pscredential]::new($secretObject.UserName, $password)
		}
		"String" {
			return [string]$secretObject.Value
		}
		"SecureString" {
			return [System.Security.SecureString](ConvertTo-SecureString -String $secretObject.Value -AsPlainText -Force)
		}
		default {
			return [System.Security.SecureString](ConvertTo-SecureString -String $normalizedPayload -AsPlainText -Force)
		}
	}
}

function Get-SecretTypeFromPayload {
	param(
		[Parameter(Mandatory)]
		[string] $Payload
	)

	$normalizedPayload = Resolve-SecretPayloadText -RawValue $Payload
	$payloadPrefix = "SM-LINUXKEYRING::"
	if (-not $normalizedPayload.StartsWith($payloadPrefix, [System.StringComparison]::Ordinal)) {
		try {
			$secretObject = $normalizedPayload | ConvertFrom-Json -ErrorAction Stop
			switch ($secretObject.Type) {
				"PSCredential" { return [Microsoft.PowerShell.SecretManagement.SecretType]::PSCredential }
				"String" { return [Microsoft.PowerShell.SecretManagement.SecretType]::String }
				default { return [Microsoft.PowerShell.SecretManagement.SecretType]::SecureString }
			}
		}
		catch {
			return [Microsoft.PowerShell.SecretManagement.SecretType]::SecureString
		}
	}

	try {
		$json = $normalizedPayload.Substring($payloadPrefix.Length)
		$secretObject = $json | ConvertFrom-Json
		switch ($secretObject.Type) {
			"PSCredential" { return [Microsoft.PowerShell.SecretManagement.SecretType]::PSCredential }
			"String" { return [Microsoft.PowerShell.SecretManagement.SecretType]::String }
			default { return [Microsoft.PowerShell.SecretManagement.SecretType]::SecureString }
		}
	}
	catch {
		return [Microsoft.PowerShell.SecretManagement.SecretType]::SecureString
	}
}

function ConvertTo-ExportSecretRecord {
	param(
		[Parameter(Mandatory)]
		[string] $Name,

		[Parameter(Mandatory)]
		[object] $Secret
	)

	if ($Secret -is [pscredential]) {
		return [ordered]@{
			Name = $Name
			Type = "PSCredential"
			UserName = $Secret.UserName
			Password = ConvertFrom-SecureStringPlainText -SecureString $Secret.Password
		}
	}

	if ($Secret -is [System.Security.SecureString]) {
		return [ordered]@{
			Name = $Name
			Type = "SecureString"
			Value = ConvertFrom-SecureStringPlainText -SecureString $Secret
		}
	}

	if ($Secret -is [string]) {
		return [ordered]@{
			Name = $Name
			Type = "String"
			Value = $Secret
		}
	}

	return [ordered]@{
		Name = $Name
		Type = "Json"
		Value = ($Secret | ConvertTo-Json -Depth 10 -Compress)
	}
}

function ConvertFrom-ImportSecretRecord {
	param(
		[Parameter(Mandatory)]
		[pscustomobject] $Record
	)

	switch ($Record.Type) {
		"PSCredential" {
			$password = ConvertTo-SecureString -String $Record.Password -AsPlainText -Force
			return [pscredential]::new($Record.UserName, $password)
		}
		"SecureString" {
			return [System.Security.SecureString](ConvertTo-SecureString -String $Record.Value -AsPlainText -Force)
		}
		"String" {
			return [string]$Record.Value
		}
		"Json" {
			return ($Record.Value | ConvertFrom-Json)
		}
		default {
			throw "Unsupported secret record type '$($Record.Type)' for secret '$($Record.Name)'."
		}
	}
}

function Get-SecretToolAttributeArgs {
	param(
		[Parameter(Mandatory)]
		[string] $Name,

		[string] $VaultName,

		[switch] $IncludeVaultName
	)

	$args = @("service", "powershell-vault", "account", $Name)
	if ($IncludeVaultName -and -not [string]::IsNullOrWhiteSpace($VaultName)) {
		$args += @("vault", $VaultName)
	}

	return $args
}

function Invoke-SecretToolLookup {
	param(
		[Parameter(Mandatory)]
		[string] $Name,

		[string] $VaultName
	)

	$scopedLookupArgs = @("lookup") + (Get-SecretToolAttributeArgs -Name $Name -VaultName $VaultName -IncludeVaultName)
	$scopedResult = & secret-tool @scopedLookupArgs 2>$null
	$scopedPayload = Resolve-SecretPayloadText -RawValue $scopedResult
	if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($scopedPayload)) {
		return $scopedPayload
	}

	if (-not [string]::IsNullOrWhiteSpace($VaultName)) {
		$legacyLookupArgs = @("lookup") + (Get-SecretToolAttributeArgs -Name $Name)
		$legacyResult = & secret-tool @legacyLookupArgs 2>$null
		$legacyPayload = Resolve-SecretPayloadText -RawValue $legacyResult
		if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($legacyPayload)) {
			return $legacyPayload
		}
	}

	return $null
}

function Invoke-SecretToolClearAll {
	param(
		[Parameter(Mandatory)]
		[string[]] $AttributeArgs
	)

	$removedAny = $false
	while ($true) {
		& secret-tool clear @AttributeArgs 2>$null | Out-Null
		if ($LASTEXITCODE -ne 0) {
			break
		}
		$removedAny = $true
	}

	return $removedAny
}

function Get-Secret {
	[CmdletBinding()]
	param(
		[string] $Name,
		[string] $VaultName,
		[hashtable] $AdditionalParameters
	)
	
	try {
		$payload = Invoke-SecretToolLookup -Name $Name -VaultName $VaultName
		if (-not [string]::IsNullOrWhiteSpace($payload)) {
			return ConvertFrom-SecretPayload -Payload $payload
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
		$secretText = ConvertTo-SecretPayload -Secret $Secret

		$scopedAttributeArgs = Get-SecretToolAttributeArgs -Name $Name -VaultName $VaultName -IncludeVaultName
		$legacyAttributeArgs = Get-SecretToolAttributeArgs -Name $Name

		# Clear stale entries first so a subsequent lookup always returns the latest value.
		$null = Invoke-SecretToolClearAll -AttributeArgs $scopedAttributeArgs
		if (-not [string]::IsNullOrWhiteSpace($VaultName)) {
			$null = Invoke-SecretToolClearAll -AttributeArgs $legacyAttributeArgs
		}

		$storeArgs = @("store", "--label", "PowerShell Secret: $Name") + $scopedAttributeArgs
		$secretText | & secret-tool @storeArgs
		return ($LASTEXITCODE -eq 0)
	}
	catch {
		Write-Error "Failed to store secret '$Name': $($_.Exception.Message)"
		return $false
	}
}

function Select-ItemsFromConsoleGrid {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[object[]] $InputObject,

		[Parameter(Mandatory)]
		[string] $Title
	)

	$gridCommand = Get-Command Out-ConsoleGridView -ErrorAction SilentlyContinue
	if (-not $gridCommand) {
		throw "Out-ConsoleGridView command not found. Install Microsoft.PowerShell.ConsoleGuiTools to use -Selected."
	}

	return @($InputObject | Out-ConsoleGridView -Title $Title -OutputMode Multiple)
}

function Export-Secret {
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[Parameter(Mandatory, ParameterSetName = "ByName")]
		[string[]] $Name,

		[Parameter(Mandatory, ParameterSetName = "All")]
		[switch] $All,

		[Parameter(Mandatory, ParameterSetName = "Selected")]
		[switch] $Selected,

		[Parameter(Mandatory)]
		[string] $Vault,

		[Parameter(Mandatory)]
		[string] $Path
	)

	Write-Warning "Exported secrets are stored as plaintext JSON. Protect this file appropriately."
	if (-not $PSCmdlet.ShouldContinue("Continue exporting secrets to plaintext file '$Path'?", "Confirm plaintext secret export")) {
		Write-Verbose "Export cancelled by user."
		return
	}

	try {
		$secretNames = switch ($PSCmdlet.ParameterSetName) {
			"All" {
				@(Microsoft.PowerShell.SecretManagement\Get-SecretInfo -Vault $Vault -ErrorAction Stop | ForEach-Object { $_.Name })
			}
			"ByName" {
				$Name
			}
			"Selected" {
				$candidates = @(Microsoft.PowerShell.SecretManagement\Get-SecretInfo -Vault $Vault -ErrorAction Stop)
				$selectedSecrets = Select-ItemsFromConsoleGrid -InputObject $candidates -Title "Select secrets to export from vault '$Vault'"
				@($selectedSecrets | ForEach-Object { $_.Name })
			}
		}

		if (-not $secretNames -or $secretNames.Count -eq 0) {
			Write-Verbose "No secrets selected for export."
			return
		}

		$records = @()
		foreach ($secretName in $secretNames) {
			$secretValue = Microsoft.PowerShell.SecretManagement\Get-Secret -Name $secretName -Vault $Vault -ErrorAction Stop
			$records += [pscustomobject](ConvertTo-ExportSecretRecord -Name $secretName -Secret $secretValue)
		}

		$resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
		$directory = Split-Path -Path $resolvedPath -Parent
		if ($directory -and -not (Test-Path -Path $directory)) {
			New-Item -ItemType Directory -Path $directory -Force | Out-Null
		}

		$records | ConvertTo-Json -Depth 10 | Set-Content -Path $resolvedPath -Encoding UTF8
		return Get-Item -Path $resolvedPath
	}
	catch {
		Write-Error "Failed to export secrets: $($_.Exception.Message)"
	}
}

function Import-Secret {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory, ParameterSetName = "ByName")]
		[string[]] $Name,

		[Parameter(Mandatory, ParameterSetName = "All")]
		[switch] $All,

		[Parameter(Mandatory, ParameterSetName = "Selected")]
		[switch] $Selected,

		[Parameter(Mandatory)]
		[string] $Vault,

		[Parameter(Mandatory)]
		[string] $Path
	)

	try {
		if (-not (Test-Path -Path $Path)) {
			throw "Import file '$Path' does not exist."
		}

		$jsonText = Get-Content -Path $Path -Raw -ErrorAction Stop
		$records = @($jsonText | ConvertFrom-Json -ErrorAction Stop)

		switch ($PSCmdlet.ParameterSetName) {
			"ByName" {
				$nameSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
				foreach ($n in $Name) {
					$null = $nameSet.Add($n)
				}
				$records = @($records | Where-Object { $nameSet.Contains($_.Name) })
			}
			"Selected" {
				$records = Select-ItemsFromConsoleGrid -InputObject $records -Title "Select secrets to import from '$Path'"
			}
		}

		if (-not $records -or $records.Count -eq 0) {
			Write-Verbose "No secrets selected for import."
			return 0
		}

		foreach ($record in $records) {
			$secretObject = ConvertFrom-ImportSecretRecord -Record $record
			$null = Microsoft.PowerShell.SecretManagement\Set-Secret -Name $record.Name -Vault $Vault -Secret $secretObject -ErrorAction Stop
		}

		return $records.Count
	}
	catch {
		Write-Error "Failed to import secrets: $($_.Exception.Message)"
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
		$scopedAttributeArgs = Get-SecretToolAttributeArgs -Name $Name -VaultName $VaultName -IncludeVaultName
		$legacyAttributeArgs = Get-SecretToolAttributeArgs -Name $Name
		$removed = Invoke-SecretToolClearAll -AttributeArgs $scopedAttributeArgs

		if (-not [string]::IsNullOrWhiteSpace($VaultName)) {
			if (Invoke-SecretToolClearAll -AttributeArgs $legacyAttributeArgs) {
				$removed = $true
			}
		}

		return $removed
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
		$seenSecretNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
		# Capture both stdout and stderr to get all output from secret-tool
		$searchOutput = $(& secret-tool search --all service "powershell-vault" 2>&1)
		if ($searchOutput) {
			$searchOutput | ForEach-Object {
				if ($_ -match "^attribute\.account = (.+)$") {
					$secretName = $Matches[1]
					if ((-not $Filter -or $secretName -like "*$Filter*") -and $seenSecretNames.Add($secretName)) {
						$payload = Invoke-SecretToolLookup -Name $secretName -VaultName $VaultName
						$secretType = if (-not [string]::IsNullOrWhiteSpace($payload)) {
							Get-SecretTypeFromPayload -Payload $payload
						}
						else {
							[Microsoft.PowerShell.SecretManagement.SecretType]::SecureString
						}
						$secrets += [Microsoft.PowerShell.SecretManagement.SecretInformation]::new(
							$secretName,
							$secretType,
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