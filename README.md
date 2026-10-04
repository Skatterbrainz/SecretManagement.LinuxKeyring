# SecretManagement.LinuxKeyring

## Overview

SecretManagement extension vault for Linux keyring (libsecret) - session-based unlocking.

## Import/Export compatibility

`Import-Secret` supports both string-based record types (for example, `"SecureString"`) and legacy numeric `SecretType` values produced by older exports (for example, `3` for `SecureString`).