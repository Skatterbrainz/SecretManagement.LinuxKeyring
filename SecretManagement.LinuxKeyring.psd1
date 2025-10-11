@{
	RootModule           = 'SecretManagement.LinuxKeyring.psm1'
	ModuleVersion        = '1.0.0'
	GUID                 = 'de5471eb-ecc7-4ee4-bac8-3882bfedf861'
	Author               = 'David Stein'
	CompanyName          = ""
	Copyright            = ""
	Description          = 'SecretManagement extension vault for Linux keyring (libsecret) - session-based unlocking'
	PowerShellVersion    = '7.4'
	CompatiblePSEditions = @('Core')
	RequiredModules      = @('Microsoft.PowerShell.SecretManagement')
    
	# Standard SecretManagement extension structure
	NestedModules        = @('SecretManagement.LinuxKeyring.Extension.psm1')
    
	FunctionsToExport    = @()
	CmdletsToExport      = @()
	VariablesToExport    = @()
	AliasesToExport      = @()
    
	PrivateData          = @{
		PSData = @{
			Tags         = @('SecretManagement', 'Secrets', 'Linux', 'Keyring', 'libsecret', 'Session')
			LicenseUri   = ""
			ProjectUri   = ""
			IconUri      = ""
			ReleaseNotes = 'SecretManagement extension for Linux keyring with session-based unlocking'
		}
	}
}