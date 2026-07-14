@{
	RootModule           = 'SecretManagement.LinuxKeyring.psm1'
	ModuleVersion        = '1.2.0'
	GUID                 = 'de5471eb-ecc7-4ee4-bac8-3882bfedf861'
	Author               = 'David Stein'
	CompanyName          = "Skatterbrainz Extrapolated Interpolations Semi-Incorporated"
	Copyright            = '© 2026 David Stein. All rights reserved.'
	Description          = 'SecretManagement extension vault for Linux keyring (libsecret) - session-based unlocking'
	PowerShellVersion    = '7.0'
	CompatiblePSEditions = @('Core')
	ProcessorArchitecture  = 'None'
	RequiredModules      = @('Microsoft.PowerShell.SecretManagement')
    
	# Standard SecretManagement extension structure
	NestedModules        = @('./SecretManagement.LinuxKeyring.Extension/SecretManagement.LinuxKeyring.Extension.psd1')

	FunctionsToExport    = @()
	CmdletsToExport      = @()
	VariablesToExport    = '*'
	AliasesToExport      = @()

	PrivateData          = @{
		PSData = @{
			Tags         = @('SecretManagement', 'Secrets', 'Linux', 'Keyring', 'libsecret', 'Session', 'skatterbrainz', 'credential', 'password')
			LicenseUri   = 'https://github.com/Skatterbrainz/SecretManagement.LinuxKeyring/blob/main/LICENSE'
			ProjectUri   = 'https://github.com/Skatterbrainz/SecretManagement.LinuxKeyring'
			#IconUri      = ""
			ReleaseNotes = "## Initial release
- SecretManagement extension for Linux keyring with session-based unlocking. Provides seamless integration with Linux desktop keyring services using libsecret."
		}
	}
}