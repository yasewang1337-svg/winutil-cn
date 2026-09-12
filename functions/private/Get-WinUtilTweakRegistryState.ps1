function Get-WinUtilTweakRegistryState {
    <# .SYNOPSIS Reads only the named value, preserving its type and unexpanded data. #>
    param([string]$Path, [AllowEmptyString()][string]$Name)
    if ($Path -match '^HKU:\\') { $Path = $Path -replace '^HKU:', 'Registry::HKEY_USERS' }
    $state = [pscustomobject]@{ Kind = 'Registry'; Path = $Path; Name = $Name; Exists = $false; ValueType = $null; Value = $null; State = 'Pending' }
    $key = $null
    try {
        $key = Get-Item -LiteralPath $Path -ErrorAction Stop
        $state.Exists = $key.GetValueNames() -contains $Name
        if ($state.Exists) {
            $state.ValueType = $key.GetValueKind($Name).ToString()
            $state.Value = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
    } catch [System.Management.Automation.ItemNotFoundException] {
        # An absent key/value is a valid snapshot, unlike denied or unreadable data.
    } finally {
        if ($null -ne $key) { $key.Dispose() }
    }
    return $state
}
