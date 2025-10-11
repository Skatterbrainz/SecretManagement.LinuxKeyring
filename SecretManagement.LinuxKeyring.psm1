# SecretManagement.LinuxKeyring - SecretManagement extension for Linux keyring (libsecret)
# 
# This module provides session-based secret storage using the Linux desktop keyring.
# Secrets are automatically unlocked when you log into your desktop session.
#
# Author: David Stein
# Copyright: © 2025 David Stein. All rights reserved.
# License: MIT

# Verify that the secret-tool command is available during module import
if (-not (Get-Command secret-tool -ErrorAction SilentlyContinue)) {
    Write-Warning "secret-tool command not found. Please install libsecret-tools package to use this SecretManagement extension."
    Write-Warning "On Ubuntu/Debian: sudo apt install libsecret-tools"
    Write-Warning "On RHEL/CentOS/Fedora: sudo dnf install libsecret-tools"
} else {
    Write-Host "SecretManagement.LinuxKeyring loaded - session-based keyring integration" -ForegroundColor Green
}