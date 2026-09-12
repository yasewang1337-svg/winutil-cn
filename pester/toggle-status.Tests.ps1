BeforeAll {
    . (Join-Path $PSScriptRoot '../functions/private/Get-WinUtilToggleStatus.ps1')
}

Describe 'Read-only toggle state (issue #6)' {
    BeforeEach {
        $script:entry = [pscustomobject]@{
            Path = 'HKCU:\Software\WinUtilTest'; Name = 'Enabled'
            Value = '1'; OriginalValue = '0'; DefaultState = 'false'
        }
        $script:sync = @{ configs = @{ tweaks = @{ Example = @{ registry = @($script:entry) } } } }
        $script:key = [pscustomobject]@{ Value = 1; Disposed = $false; Requested = '' }
        $script:key | Add-Member ScriptMethod GetValue {
            param($name, $default, $options)
            $this.Requested = $name
            return $this.Value
        }
        $script:key | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
        Mock Get-Item { $script:key }
        Mock Get-ItemProperty { throw [InvalidCastException]::new('Unrelated malformed value') }
        Mock New-Item { throw 'A status read must never write registry keys' }
        Mock New-PSDrive { throw 'A status read must not create drives' }
        Mock Write-Warning {}
    }

    It 'reads only the requested value without enumerating unrelated values' {
        Get-WinUtilToggleStatus Example | Should -BeTrue
        $script:key.Requested | Should -Be 'Enabled'
        $script:key.Disposed | Should -BeTrue
        Should -Invoke Get-ItemProperty -Times 0 -Exactly
        Should -Invoke New-Item -Times 0 -Exactly
    }

    It 'uses the configured default when a key is absent' {
        Mock Get-Item { throw [System.Management.Automation.ItemNotFoundException]::new('missing') }
        Get-WinUtilToggleStatus Example | Should -BeFalse
        $script:entry.DefaultState = 'true'
        Get-WinUtilToggleStatus Example | Should -BeTrue
        Should -Invoke New-Item -Times 0 -Exactly
    }

    It 'uses the configured default for an absent value, including boolean defaults' {
        $script:key.Value = $null
        $script:entry.DefaultState = $true
        Get-WinUtilToggleStatus Example | Should -BeTrue
    }

    It 'reports an unreadable value without aborting startup or claiming it is enabled' {
        $script:key | Add-Member ScriptMethod GetValue { throw [InvalidCastException]::new('invalid value') } -Force
        Get-WinUtilToggleStatus Example | Should -BeFalse
        $script:key.Disposed | Should -BeTrue
        Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -like '*Enabled*' }
    }

    It 'handles denied registry access without aborting startup' {
        Mock Get-Item { throw [UnauthorizedAccessException]::new('denied') }
        Get-WinUtilToggleStatus Example | Should -BeFalse
        Should -Invoke Write-Warning -Times 1 -Exactly
    }

    It 'resolves HKU without creating a drive' {
        $script:entry.Path = 'HKU:\.DEFAULT\Software\WinUtilTest'
        Get-WinUtilToggleStatus Example | Should -BeTrue
        Should -Invoke Get-Item -Times 1 -Exactly -ParameterFilter {
            $LiteralPath -eq 'Registry::HKEY_USERS\.DEFAULT\Software\WinUtilTest'
        }
        Should -Invoke New-PSDrive -Times 0 -Exactly
    }

    It 'observes changes on subsequent reads instead of returning stale state' {
        Get-WinUtilToggleStatus Example | Should -BeTrue
        $script:key.Value = 0
        Get-WinUtilToggleStatus Example | Should -BeFalse
    }
}
